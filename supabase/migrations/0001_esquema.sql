-- =====================================================================
-- Estudo Musical — MSA · esquema do banco
-- =====================================================================
-- O app nasceu guardando tudo no aparelho (localStorage). Aqui o mesmo
-- modelo vira tabelas, para o progresso sobreviver à troca de celular e o
-- encarregado enxergar a turma inteira de onde estiver.
--
-- Duas decisões que valem para o arquivo todo:
--
-- 1. Chaves de texto, não uuid gerado pelo banco. O app cria conteúdo
--    offline com ids do tipo 'met-lq3k8-a9f2'; mantendo esses ids como
--    chave primária, o que foi criado sem internet sobe depois sem
--    precisar reescrever referência nenhuma.
--
-- 2. `atualizado_em` em tudo que se edita. É por esse campo que a
--    sincronização sabe o que mudou desde a última visita, e quem ganha
--    quando dois aparelhos mexeram no mesmo registro.
--
-- Ordem: 0001 esquema · 0002 funções · 0003 políticas de acesso.
-- =====================================================================

-- --------------------------------------------------------------- tipos

do $$ begin
  create type public.papel as enum ('administrador', 'encarregado', 'instrutor', 'aluno');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.status_questao as enum ('rascunho', 'publicada');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.status_turma as enum ('rascunho', 'em-avaliacao', 'liberada');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.status_matricula as enum ('ativo', 'inativo');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.status_sugestao as enum ('aberta', 'aplicada', 'recusada');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.status_curso as enum ('RASCUNHO', 'EM_ANALISE', 'APROVADO', 'PUBLICADO', 'ARQUIVADO');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.voto_avaliacao as enum ('aprovado', 'ajustes');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.operador_requisito as enum ('TODOS', 'QUALQUER');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.modo_liberacao as enum ('automatico', 'manual');
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------- carimbo de hora

create or replace function public.marcar_atualizacao()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

-- =====================================================================
-- Pessoas
-- =====================================================================

-- Uma linha por usuário do Supabase Auth. A senha não mora aqui: fica no
-- `auth.users`, verificada pelo servidor. `conta_local` guarda o id que a
-- pessoa tinha na instalação offline ('admin', 'alu-teste', 'ins-lq3k8…'),
-- para as matrículas e o histórico antigos encontrarem o dono na primeira
-- sincronização.
create table if not exists public.perfis (
  id            uuid primary key references auth.users (id) on delete cascade,
  nome          text not null,
  perfil        public.papel not null default 'aluno',
  instrumento   text not null default '',
  conta_local   text unique,
  xp            integer not null default 0 check (xp >= 0),
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists perfis_perfil_idx on public.perfis (perfil);

drop trigger if exists perfis_atualizacao on public.perfis;
create trigger perfis_atualizacao before update on public.perfis
  for each row execute function public.marcar_atualizacao();

-- Chave/valor do sistema. Hoje guarda só `mostrarMsa` (se o método
-- embutido aparece para os alunos), mas é o lugar de qualquer ajuste
-- global que apareça depois.
create table if not exists public.configuracoes (
  chave         text primary key,
  valor         jsonb not null,
  atualizado_em timestamptz not null default now()
);

drop trigger if exists configuracoes_atualizacao on public.configuracoes;
create trigger configuracoes_atualizacao before update on public.configuracoes
  for each row execute function public.marcar_atualizacao();

insert into public.configuracoes (chave, valor)
values ('mostrarMsa', 'true'::jsonb)
on conflict (chave) do nothing;

-- Instrumentos cadastrados além do catálogo que já vem no app.
create table if not exists public.instrumentos (
  id            text primary key,
  nome          text not null,
  familia       text not null default 'Outros',
  chaves        text[] not null default '{}',
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

drop trigger if exists instrumentos_atualizacao on public.instrumentos;
create trigger instrumentos_atualizacao before update on public.instrumentos
  for each row execute function public.marcar_atualizacao();

-- =====================================================================
-- Conteúdo: método → fase → lição / questão / jogo
-- =====================================================================

create table if not exists public.metodos (
  id            text primary key,
  nome          text not null,
  instrumento   text not null default 'Geral',
  descricao     text not null default '',
  tipo          text not null default 'metodo',
  tonalidade    text not null default '',
  cor           text not null default '#2f9e6b',
  icone         text not null default '🎵',
  publicado     boolean not null default false,
  criado_por    uuid references public.perfis (id) on delete set null,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists metodos_publicado_idx on public.metodos (publicado);

drop trigger if exists metodos_atualizacao on public.metodos;
create trigger metodos_atualizacao before update on public.metodos
  for each row execute function public.marcar_atualizacao();

-- `ordem` é a posição na lista, e não uma chave: o painel reordena fases
-- o tempo todo, então não há unicidade — só um índice para ler na ordem.
create table if not exists public.fases (
  id            text primary key,
  metodo_id     text not null references public.metodos (id) on delete cascade,
  ordem         integer not null default 0,
  titulo        text not null,
  subtitulo     text not null default '',
  resumo        text not null default '',
  paginas       text not null default '',
  icone         text not null default '🎼',
  pares         jsonb not null default '[]'::jsonb,
  atualizado_em timestamptz not null default now()
);

create index if not exists fases_metodo_idx on public.fases (metodo_id, ordem);

drop trigger if exists fases_atualizacao on public.fases;
create trigger fases_atualizacao before update on public.fases
  for each row execute function public.marcar_atualizacao();

create table if not exists public.licoes (
  id            text primary key,
  fase_id       text not null references public.fases (id) on delete cascade,
  ordem         integer not null default 0,
  titulo        text not null default 'Nova lição',
  pagina        text not null default '',
  corpo         text not null default '',
  atualizado_em timestamptz not null default now()
);

create index if not exists licoes_fase_idx on public.licoes (fase_id, ordem);

drop trigger if exists licoes_atualizacao on public.licoes;
create trigger licoes_atualizacao before update on public.licoes
  for each row execute function public.marcar_atualizacao();

-- `assinatura` é o hash de enunciado+resposta que o app já usa para não
-- repetir pergunta; fica gravada para o sorteio funcionar igual offline e
-- online, e para barrar questão duplicada na importação.
create table if not exists public.questoes (
  id            text primary key,
  fase_id       text not null references public.fases (id) on delete cascade,
  enunciado     text not null,
  alternativas  jsonb not null default '[]'::jsonb,
  correta       text not null default '',
  explicacao    text not null default '',
  status        public.status_questao not null default 'rascunho',
  assinatura    text not null default '',
  origem        text not null default '',
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists questoes_fase_idx on public.questoes (fase_id, status);
create unique index if not exists questoes_assinatura_idx on public.questoes (fase_id, assinatura)
  where assinatura <> '';

drop trigger if exists questoes_atualizacao on public.questoes;
create trigger questoes_atualizacao before update on public.questoes
  for each row execute function public.marcar_atualizacao();

create table if not exists public.jogos (
  id            text primary key,
  fase_id       text not null references public.fases (id) on delete cascade,
  ordem         integer not null default 0,
  tipo          text not null,
  titulo        text not null default '',
  descricao     text not null default '',
  config        jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now()
);

create index if not exists jogos_fase_idx on public.jogos (fase_id, ordem);

drop trigger if exists jogos_atualizacao on public.jogos;
create trigger jogos_atualizacao before update on public.jogos
  for each row execute function public.marcar_atualizacao();

-- =====================================================================
-- Turmas: conteúdo na ordem de estudo + níveis de acesso + matrículas
-- =====================================================================

create table if not exists public.turmas (
  id            text primary key,
  nome          text not null,
  instrumento   text not null default '',
  status        public.status_turma not null default 'rascunho',
  criada_em     timestamptz not null default now(),
  enviada_em    timestamptz,
  liberada_em   timestamptz,
  criada_por    uuid references public.perfis (id) on delete set null,
  atualizado_em timestamptz not null default now()
);

create index if not exists turmas_status_idx on public.turmas (status, instrumento);

drop trigger if exists turmas_atualizacao on public.turmas;
create trigger turmas_atualizacao before update on public.turmas
  for each row execute function public.marcar_atualizacao();

-- `fonte` é 'msa' (o método embutido) ou o id de um método cadastrado.
-- Fica como texto de propósito: o método embutido não é uma linha de
-- `metodos`, então uma chave estrangeira aqui impediria de usá-lo.
create table if not exists public.turma_conteudos (
  turma_id text not null references public.turmas (id) on delete cascade,
  fonte    text not null,
  ordem    integer not null default 0,
  primary key (turma_id, fonte)
);

create index if not exists turma_conteudos_ordem_idx on public.turma_conteudos (turma_id, ordem);

create table if not exists public.turma_instrutores (
  turma_id     text not null references public.turmas (id) on delete cascade,
  instrutor_id uuid not null references public.perfis (id) on delete cascade,
  desde        timestamptz not null default now(),
  primary key (turma_id, instrutor_id)
);

-- Um voto por instrutor por turma: o app já substitui o voto anterior, e a
-- chave primária faz o banco garantir o mesmo.
create table if not exists public.turma_avaliacoes (
  turma_id     text not null references public.turmas (id) on delete cascade,
  instrutor_id uuid not null references public.perfis (id) on delete cascade,
  voto         public.voto_avaliacao not null,
  comentario   text not null default '',
  data         timestamptz not null default now(),
  primary key (turma_id, instrutor_id),
  constraint ajuste_exige_comentario check (voto <> 'ajustes' or length(trim(comentario)) > 0)
);

create table if not exists public.niveis (
  id              text primary key,
  turma_id        text not null references public.turmas (id) on delete cascade,
  nome            text not null,
  ordem           integer not null default 0,
  operador        public.operador_requisito not null default 'TODOS',
  modo_liberacao  public.modo_liberacao not null default 'automatico',
  atualizado_em   timestamptz not null default now()
);

create index if not exists niveis_turma_idx on public.niveis (turma_id, ordem);

drop trigger if exists niveis_atualizacao on public.niveis;
create trigger niveis_atualizacao before update on public.niveis
  for each row execute function public.marcar_atualizacao();

-- O que este nível libera de cada conteúdo: da fase `de` até a fase `ate`.
create table if not exists public.nivel_regras (
  nivel_id        text not null references public.niveis (id) on delete cascade,
  fonte           text not null,
  de              integer not null default 1 check (de >= 1),
  ate             integer not null default 1,
  paginas         text not null default '',
  exige_anterior  boolean not null default false,
  operador        public.operador_requisito not null default 'TODOS',
  primary key (nivel_id, fonte),
  constraint faixa_valida check (ate >= de)
);

-- Requisito de percentual. Com `regra_fonte` nulo, é o que se exige para
-- ENTRAR no nível; preenchido, é o que libera aquele conteúdo dentro do
-- nível. A chave estrangeira composta só vale quando `regra_fonte` existe
-- (MATCH SIMPLE ignora a linha quando qualquer coluna é nula), que é
-- exatamente a distinção entre os dois casos.
create table if not exists public.nivel_requisitos (
  id                 bigint generated always as identity primary key,
  nivel_id           text not null references public.niveis (id) on delete cascade,
  regra_fonte        text,
  fonte              text not null,
  percentual_minimo  numeric(5,2) not null default 0 check (percentual_minimo between 0 and 100),
  foreign key (nivel_id, regra_fonte) references public.nivel_regras (nivel_id, fonte) on delete cascade
);

create index if not exists nivel_requisitos_idx on public.nivel_requisitos (nivel_id, regra_fonte);

-- Um aluno só tem uma matrícula por turma; o nível é o que ele enxerga.
create table if not exists public.matriculas (
  turma_id      text not null references public.turmas (id) on delete cascade,
  aluno_id      uuid not null references public.perfis (id) on delete cascade,
  nivel_id      text references public.niveis (id) on delete set null,
  status        public.status_matricula not null default 'ativo',
  desde         timestamptz not null default now(),
  progresso     jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now(),
  primary key (turma_id, aluno_id)
);

create index if not exists matriculas_aluno_idx on public.matriculas (aluno_id);

drop trigger if exists matriculas_atualizacao on public.matriculas;
create trigger matriculas_atualizacao before update on public.matriculas
  for each row execute function public.marcar_atualizacao();

-- Promoção nunca apaga a evolução anterior: cada troca de nível vira uma
-- linha aqui, com o retrato do progresso no momento da mudança.
create table if not exists public.matricula_historico (
  id          bigint generated always as identity primary key,
  turma_id    text not null,
  aluno_id    uuid not null,
  data        timestamptz not null default now(),
  de          text not null default '',
  para        text not null default '',
  por_quem    text not null default 'sistema',
  motivo      text not null default '',
  observacao  text not null default '',
  progresso   jsonb not null default '{}'::jsonb,
  foreign key (turma_id, aluno_id) references public.matriculas (turma_id, aluno_id) on delete cascade
);

create index if not exists matricula_historico_idx on public.matricula_historico (turma_id, aluno_id, data);

-- =====================================================================
-- Progresso do aluno
-- =====================================================================
-- `fase_ref` aponta para uma fase de qualquer origem: '1'…'10' são as
-- fases do método embutido, e 'm:<metodo>:<fase>' as de método cadastrado.
-- É a mesma chave que o app já usa no aparelho, mantida de propósito.

create table if not exists public.progresso_fases (
  aluno_id      uuid not null references public.perfis (id) on delete cascade,
  fase_ref      text not null,
  licoes_lidas  integer[] not null default '{}',
  jogos         jsonb not null default '{}'::jsonb,
  aprovado_em   timestamptz,
  melhor_nota   integer not null default 0 check (melhor_nota between 0 and 100),
  atualizado_em timestamptz not null default now(),
  primary key (aluno_id, fase_ref)
);

drop trigger if exists progresso_fases_atualizacao on public.progresso_fases;
create trigger progresso_fases_atualizacao before update on public.progresso_fases
  for each row execute function public.marcar_atualizacao();

-- Cada prova feita. O id vem do aparelho para a mesma tentativa não entrar
-- duas vezes quando a sincronização é repetida.
create table if not exists public.tentativas (
  id        text primary key,
  aluno_id  uuid not null references public.perfis (id) on delete cascade,
  fase_ref  text not null,
  data      timestamptz not null default now(),
  acertos   integer not null default 0 check (acertos >= 0),
  total     integer not null default 0 check (total >= 0),
  nota      integer not null default 0 check (nota between 0 and 100),
  aprovado  boolean not null default false,
  semente   bigint,
  constraint acertos_cabem_no_total check (acertos <= total)
);

create index if not exists tentativas_aluno_idx on public.tentativas (aluno_id, fase_ref, data);

-- Assinaturas de questões já sorteadas, para não repetir pergunta.
create table if not exists public.questoes_usadas (
  aluno_id   uuid not null references public.perfis (id) on delete cascade,
  fase_ref   text not null,
  assinatura text not null,
  primary key (aluno_id, fase_ref, assinatura)
);

-- Um certificado por fase concluída. Os campos do texto impresso ficam
-- gravados como estavam no dia: se a fase for reescrita depois, o
-- certificado antigo continua dizendo a verdade daquele dia.
create table if not exists public.certificados (
  aluno_id   uuid not null references public.perfis (id) on delete cascade,
  fase_ref   text not null,
  nome       text not null,
  titulo     text not null default '',
  subtitulo  text not null default '',
  paginas    text not null default '',
  cor        text not null default '#2f9e6b',
  nota       integer not null default 0 check (nota between 0 and 100),
  acertos    integer not null default 0,
  total      integer not null default 0,
  data       timestamptz not null default now(),
  codigo     text not null,
  primary key (aluno_id, fase_ref)
);

create index if not exists certificados_codigo_idx on public.certificados (codigo);

-- =====================================================================
-- Sugestões, cursos gerados e auditoria
-- =====================================================================

create table if not exists public.sugestoes (
  id            text primary key,
  autor_id      uuid references public.perfis (id) on delete set null,
  autor_nome    text not null default 'Anônimo',
  perfil        public.papel not null default 'aluno',
  metodo_id     text references public.metodos (id) on delete set null,
  fase_id       text references public.fases (id) on delete set null,
  texto         text not null check (length(trim(texto)) > 0),
  status        public.status_sugestao not null default 'aberta',
  data          timestamptz not null default now(),
  resolvida_em  timestamptz
);

create index if not exists sugestoes_status_idx on public.sugestoes (status, data);

-- Curso montado a partir de documentos importados. Continua em jsonb
-- porque é rascunho em evolução: só ao publicar é que ele vira método,
-- fase, lição e questão de verdade, nas tabelas de cima.
create table if not exists public.cursos (
  id            text primary key,
  titulo        text not null default '',
  status        public.status_curso not null default 'RASCUNHO',
  metadados     jsonb not null default '{}'::jsonb,
  documentos    jsonb not null default '[]'::jsonb,
  fases         jsonb not null default '[]'::jsonb,
  versoes       jsonb not null default '[]'::jsonb,
  alteracoes    jsonb not null default '[]'::jsonb,
  criado_por    uuid references public.perfis (id) on delete set null,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists cursos_status_idx on public.cursos (status);

drop trigger if exists cursos_atualizacao on public.cursos;
create trigger cursos_atualizacao before update on public.cursos
  for each row execute function public.marcar_atualizacao();

-- Quem fez o quê, quando. Sem update e sem delete: as políticas de acesso
-- do 0003 só permitem inserir e ler.
create table if not exists public.auditoria (
  id            text primary key,
  usuario_id    uuid references public.perfis (id) on delete set null,
  usuario_nome  text not null default 'sem sessão',
  perfil        text not null default 'anônimo',
  acao          text not null,
  entidade      text not null default '',
  entidade_id   text not null default '',
  detalhes      text not null default '',
  data          timestamptz not null default now()
);

create index if not exists auditoria_data_idx on public.auditoria (data desc);
create index if not exists auditoria_usuario_idx on public.auditoria (usuario_id, data desc);
