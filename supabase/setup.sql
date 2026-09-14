-- ===================================================================
-- Estudo Musical — MSA · instalação do banco numa colada só
-- ===================================================================
-- ARQUIVO GERADO por gerar-setup.sh — não edite aqui.
-- É a junção de migrations/*.sql, na ordem. Mexer no banco se faz
-- nas migrações; este arquivo é só a comodidade de instalar tudo de
-- uma vez, colando no Editor SQL do Supabase.
-- ===================================================================


-- >>>>>>>>>>>>>>>>>>>>>>>>>> migrations/0001_esquema.sql

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

-- >>>>>>>>>>>>>>>>>>>>>>>>>> migrations/0002_funcoes.sql

-- =====================================================================
-- Estudo Musical — MSA · funções
-- =====================================================================
-- Três assuntos: quem é quem (papel do usuário), como nasce um perfil, e
-- como o progresso de dois aparelhos vira um só sem ninguém perder nada.
-- =====================================================================

-- ------------------------------------------------------- quem está usando

-- Lê o papel de quem chamou. É SECURITY DEFINER de propósito: as políticas
-- de acesso de `perfis` precisam consultar `perfis`, e sem isso a consulta
-- chamaria a política de novo, sem fim.
create or replace function public.papel_atual()
returns public.papel
language sql
security definer
set search_path = public
stable
as $$
  select perfil from public.perfis where id = auth.uid();
$$;

create or replace function public.tem_gestao()
returns boolean
language sql
stable
as $$
  select public.papel_atual() in ('administrador', 'encarregado');
$$;

-- Encarregado, administrador e instrutor: quem acompanha turma e progresso.
create or replace function public.tem_painel()
returns boolean
language sql
stable
as $$
  select public.papel_atual() in ('administrador', 'encarregado', 'instrutor');
$$;

-- --------------------------------------------------------- novo cadastro

-- Todo usuário do Auth ganha uma linha em `perfis`.
--
-- O papel NUNCA vem do cadastro: quem se inscreve entra como aluno, e só um
-- administrador promove depois. Os dados que o próprio usuário manda na
-- inscrição são escolhidos por ele — aceitar um 'perfil' dali seria deixar
-- qualquer visitante se declarar administrador.
--
-- A exceção é a primeira conta do sistema, que vira administrador para o
-- painel não nascer trancado. (Duas inscrições ao mesmo tempo num banco
-- recém-criado poderiam gerar dois administradores; na prática a primeira
-- conta é criada por quem está instalando.)
create or replace function public.criar_perfil_do_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  primeiro boolean;
begin
  select not exists (select 1 from public.perfis) into primeiro;

  insert into public.perfis (id, nome, perfil, instrumento, conta_local)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'nome', ''), split_part(new.email, '@', 1)),
    case when primeiro then 'administrador'::public.papel else 'aluno'::public.papel end,
    coalesce(new.raw_user_meta_data ->> 'instrumento', ''),
    nullif(new.raw_user_meta_data ->> 'contaLocal', '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.criar_perfil_do_usuario();

-- Promover é ato de administrador. A política de acesso trabalha por
-- linha, então a coluna `perfil` precisa desta trava à parte: sem ela, um
-- aluno editando o próprio nome poderia editar o próprio papel junto.
create or replace function public.proteger_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.perfil is distinct from old.perfil and public.papel_atual() <> 'administrador' then
    raise exception 'Só um administrador muda o papel de uma conta.';
  end if;
  return new;
end;
$$;

drop trigger if exists perfis_protege_papel on public.perfis;
create trigger perfis_protege_papel before update on public.perfis
  for each row execute function public.proteger_papel();

-- ------------------------------------------------------------- mesclagem

-- União de duas listas de lições lidas, sem repetir e em ordem.
create or replace function public.unir_inteiros(a integer[], b integer[])
returns integer[]
language sql
immutable
as $$
  select coalesce(array(
    select distinct valor from unnest(coalesce(a, '{}') || coalesce(b, '{}')) as valor order by valor
  ), '{}');
$$;

-- Melhor pontuação de cada jogo entre dois aparelhos. Quem jogou melhor no
-- celular não perde a marca por ter aberto o app no computador depois.
create or replace function public.maior_pontuacao(a jsonb, b jsonb)
returns jsonb
language sql
immutable
as $$
  select coalesce(
    (
      select jsonb_object_agg(chave, maior)
      from (
        select chave, max(valor) as maior
        from (
          select key as chave, (value #>> '{}')::numeric as valor from jsonb_each(coalesce(a, '{}'::jsonb))
          union all
          select key as chave, (value #>> '{}')::numeric as valor from jsonb_each(coalesce(b, '{}'::jsonb))
        ) as tudo
        group by chave
      ) as juntos
    ),
    '{}'::jsonb
  );
$$;

-- O progresso de quem chamou, no mesmo formato que o app usa no aparelho.
create or replace function public.meu_progresso()
returns jsonb
language sql
security invoker
set search_path = public
stable
as $$
  select jsonb_build_object(
    'versao', 1,
    'aluno', jsonb_build_object(
      'nome', coalesce(p.nome, ''),
      'criadoEm', p.criado_em
    ),
    'xp', p.xp,
    'fases', coalesce((
      select jsonb_object_agg(f.fase_ref, jsonb_build_object(
        'licoesLidas', to_jsonb(f.licoes_lidas),
        'jogos', f.jogos,
        'aprovadoEm', f.aprovado_em,
        'melhorNota', f.melhor_nota,
        'tentativas', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', t.id, 'data', t.data, 'acertos', t.acertos,
            'total', t.total, 'nota', t.nota, 'aprovado', t.aprovado, 'semente', t.semente
          ) order by t.data)
          from public.tentativas t
          where t.aluno_id = f.aluno_id and t.fase_ref = f.fase_ref
        ), '[]'::jsonb)
      ))
      from public.progresso_fases f
      where f.aluno_id = p.id
    ), '{}'::jsonb),
    'usadas', coalesce((
      select jsonb_object_agg(u.fase_ref, u.lista)
      from (
        select fase_ref, jsonb_agg(assinatura) as lista
        from public.questoes_usadas
        where aluno_id = p.id
        group by fase_ref
      ) u
    ), '{}'::jsonb),
    'certificados', coalesce((
      select jsonb_agg(jsonb_build_object(
        -- Volta como número nas fases do método embutido, que é como o app
        -- compara certificado com fase.
        'fase', case when c.fase_ref ~ '^[0-9]+$' then to_jsonb(c.fase_ref::integer) else to_jsonb(c.fase_ref) end,
        'nome', c.nome, 'titulo', c.titulo, 'subtitulo', c.subtitulo, 'paginas', c.paginas,
        'cor', c.cor, 'nota', c.nota, 'acertos', c.acertos, 'total', c.total,
        'data', c.data, 'codigo', c.codigo
      ) order by c.fase_ref)
      from public.certificados c
      where c.aluno_id = p.id
    ), '[]'::jsonb)
  )
  from public.perfis p
  where p.id = auth.uid();
$$;

-- =====================================================================
-- sincronizar_progresso(dados jsonb) -> jsonb
-- =====================================================================
-- Recebe o progresso como ele está no aparelho, junta com o que já existe
-- no banco e devolve o resultado da junção — que o app grava de volta por
-- cima do que tinha. Funciona nos dois sentidos numa chamada só.
--
-- As regras de junção são escolhidas para nunca apagar esforço:
--   lições lidas ....... união
--   pontos de jogo ..... o maior
--   melhor nota ........ a maior
--   aprovado em ........ a data mais antiga (a aprovação de verdade)
--   tentativas ......... todas, sem repetir (id vindo do aparelho)
--   questões usadas .... união
--   certificados ....... o de maior nota
--   xp ................. o maior
--
-- Por isso duas pessoas no mesmo login, ou a mesma pessoa em dois
-- aparelhos, nunca geram conflito: não há decisão a tomar.
create or replace function public.sincronizar_progresso(dados jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  eu uuid := auth.uid();
  fase record;
  tentativa jsonb;
  certificado jsonb;
  usada record;
  nome_local text;
begin
  if eu is null then
    raise exception 'Entre na sua conta para sincronizar.';
  end if;

  -- O nome do perfil manda; o do aparelho só preenche se ainda não houver.
  nome_local := nullif(trim(coalesce(dados #>> '{aluno,nome}', '')), '');
  if nome_local is not null then
    update public.perfis set nome = nome_local where id = eu and trim(nome) = '';
  end if;

  update public.perfis
     set xp = greatest(xp, coalesce((dados ->> 'xp')::integer, 0))
   where id = eu;

  -- ----------------------------------------------------------- fases
  for fase in
    select key as ref, value as corpo from jsonb_each(coalesce(dados -> 'fases', '{}'::jsonb))
  loop
    insert into public.progresso_fases (aluno_id, fase_ref, licoes_lidas, jogos, aprovado_em, melhor_nota)
    values (
      eu,
      fase.ref,
      coalesce((
        select array_agg(valor::integer order by valor::integer)
        from jsonb_array_elements_text(coalesce(fase.corpo -> 'licoesLidas', '[]'::jsonb)) as valor
      ), '{}'),
      coalesce(fase.corpo -> 'jogos', '{}'::jsonb),
      nullif(fase.corpo ->> 'aprovadoEm', '')::timestamptz,
      least(100, greatest(0, coalesce((fase.corpo ->> 'melhorNota')::numeric, 0)))::integer
    )
    on conflict (aluno_id, fase_ref) do update set
      licoes_lidas = public.unir_inteiros(progresso_fases.licoes_lidas, excluded.licoes_lidas),
      jogos        = public.maior_pontuacao(progresso_fases.jogos, excluded.jogos),
      aprovado_em  = least(progresso_fases.aprovado_em, excluded.aprovado_em),
      melhor_nota  = greatest(progresso_fases.melhor_nota, excluded.melhor_nota),
      atualizado_em = now();

    -- ------------------------------------------------------ tentativas
    for tentativa in
      select valor from jsonb_array_elements(coalesce(fase.corpo -> 'tentativas', '[]'::jsonb)) as valor
    loop
      insert into public.tentativas (id, aluno_id, fase_ref, data, acertos, total, nota, aprovado, semente)
      values (
        -- Tentativa antiga não tem id: um hash do conteúdo serve de
        -- identidade estável, para não duplicar a cada sincronização.
        coalesce(
          nullif(tentativa ->> 'id', ''),
          'ten-' || md5(
            eu::text || '|' || fase.ref || '|' || coalesce(tentativa ->> 'data', '') || '|' ||
            coalesce(tentativa ->> 'nota', '') || '|' || coalesce(tentativa ->> 'acertos', '')
          )
        ),
        eu,
        fase.ref,
        coalesce(nullif(tentativa ->> 'data', '')::timestamptz, now()),
        greatest(0, coalesce((tentativa ->> 'acertos')::integer, 0)),
        greatest(0, coalesce((tentativa ->> 'total')::integer, 0)),
        least(100, greatest(0, coalesce((tentativa ->> 'nota')::numeric, 0)))::integer,
        coalesce((tentativa ->> 'aprovado')::boolean, false),
        nullif(tentativa ->> 'semente', '')::bigint
      )
      on conflict (id) do nothing;
    end loop;
  end loop;

  -- -------------------------------------------------- questões usadas
  for usada in
    select chave.key as ref, assinatura
    from jsonb_each(coalesce(dados -> 'usadas', '{}'::jsonb)) as chave,
         jsonb_array_elements_text(chave.value) as assinatura
  loop
    insert into public.questoes_usadas (aluno_id, fase_ref, assinatura)
    values (eu, usada.ref, usada.assinatura)
    on conflict do nothing;
  end loop;

  -- ------------------------------------------------------ certificados
  for certificado in
    select valor from jsonb_array_elements(coalesce(dados -> 'certificados', '[]'::jsonb)) as valor
  loop
    insert into public.certificados (aluno_id, fase_ref, nome, titulo, subtitulo, paginas, cor, nota, acertos, total, data, codigo)
    values (
      eu,
      coalesce(nullif(certificado ->> 'fase', ''), '0'),
      coalesce(certificado ->> 'nome', ''),
      coalesce(certificado ->> 'titulo', ''),
      coalesce(certificado ->> 'subtitulo', ''),
      coalesce(certificado ->> 'paginas', ''),
      coalesce(nullif(certificado ->> 'cor', ''), '#2f9e6b'),
      least(100, greatest(0, coalesce((certificado ->> 'nota')::numeric, 0)))::integer,
      greatest(0, coalesce((certificado ->> 'acertos')::integer, 0)),
      greatest(0, coalesce((certificado ->> 'total')::integer, 0)),
      coalesce(nullif(certificado ->> 'data', '')::timestamptz, now()),
      coalesce(certificado ->> 'codigo', '')
    )
    on conflict (aluno_id, fase_ref) do update set
      nota    = greatest(certificados.nota, excluded.nota),
      acertos = case when excluded.nota >= certificados.nota then excluded.acertos else certificados.acertos end,
      total   = case when excluded.nota >= certificados.nota then excluded.total else certificados.total end,
      data    = case when excluded.nota >= certificados.nota then excluded.data else public.certificados.data end,
      codigo  = case when excluded.nota >= certificados.nota then excluded.codigo else certificados.codigo end;
  end loop;

  return public.meu_progresso();
end;
$$;

-- ------------------------------------------------------- visibilidade

-- Aluno só enxerga conteúdo publicado; quem tem painel enxerga o rascunho
-- também. As duas funções abaixo evitam repetir essa mesma sub-consulta em
-- cada política de fase, lição, questão e jogo.
create or replace function public.metodo_visivel(id_metodo text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.tem_painel()
      or exists (select 1 from public.metodos m where m.id = id_metodo and m.publicado);
$$;

create or replace function public.fase_visivel(id_fase text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.fases f
     where f.id = id_fase and public.metodo_visivel(f.metodo_id)
  );
$$;

-- >>>>>>>>>>>>>>>>>>>>>>>>>> migrations/0003_politicas.sql

-- =====================================================================
-- Estudo Musical — MSA · políticas de acesso (Row Level Security)
-- =====================================================================
-- O app é uma página estática: a chave que ele carrega é pública e qualquer
-- pessoa pode lê-la no navegador. Quem separa os dados, então, é este
-- arquivo — não o app. Toda tabela nasce trancada e só abre pelo que está
-- escrito aqui.
--
-- Em resumo:
--   aluno ........ mexe no próprio progresso e lê o conteúdo publicado
--   instrutor .... lê turma e progresso, e vota nas turmas do instrumento
--   encarregado .. cadastra conteúdo, turmas e matrículas
--   administrador  tudo isso e mais promover contas
--
-- Toda política é `to authenticated`: visitante sem conta não lê nada.
-- =====================================================================

alter table public.perfis              enable row level security;
alter table public.configuracoes       enable row level security;
alter table public.instrumentos        enable row level security;
alter table public.metodos             enable row level security;
alter table public.fases               enable row level security;
alter table public.licoes              enable row level security;
alter table public.questoes            enable row level security;
alter table public.jogos               enable row level security;
alter table public.turmas              enable row level security;
alter table public.turma_conteudos     enable row level security;
alter table public.turma_instrutores   enable row level security;
alter table public.turma_avaliacoes    enable row level security;
alter table public.niveis              enable row level security;
alter table public.nivel_regras        enable row level security;
alter table public.nivel_requisitos    enable row level security;
alter table public.matriculas          enable row level security;
alter table public.matricula_historico enable row level security;
alter table public.progresso_fases     enable row level security;
alter table public.tentativas          enable row level security;
alter table public.questoes_usadas     enable row level security;
alter table public.certificados        enable row level security;
alter table public.sugestoes           enable row level security;
alter table public.cursos              enable row level security;
alter table public.auditoria           enable row level security;

-- ------------------------------------------------------------- perfis

drop policy if exists perfis_leitura on public.perfis;
create policy perfis_leitura on public.perfis
  for select to authenticated
  using (id = auth.uid() or public.tem_painel());

drop policy if exists perfis_insercao on public.perfis;
create policy perfis_insercao on public.perfis
  for insert to authenticated
  with check (id = auth.uid());

-- A coluna `perfil` tem trava própria no gatilho `proteger_papel`: aqui a
-- pessoa pode editar o próprio cadastro, mas não o próprio papel.
drop policy if exists perfis_edicao on public.perfis;
create policy perfis_edicao on public.perfis
  for update to authenticated
  using (id = auth.uid() or public.papel_atual() = 'administrador')
  with check (id = auth.uid() or public.papel_atual() = 'administrador');

drop policy if exists perfis_exclusao on public.perfis;
create policy perfis_exclusao on public.perfis
  for delete to authenticated
  using (public.papel_atual() = 'administrador');

-- ------------------------------------------- configurações e instrumentos

drop policy if exists configuracoes_leitura on public.configuracoes;
create policy configuracoes_leitura on public.configuracoes
  for select to authenticated using (true);

drop policy if exists configuracoes_escrita on public.configuracoes;
create policy configuracoes_escrita on public.configuracoes
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists instrumentos_leitura on public.instrumentos;
create policy instrumentos_leitura on public.instrumentos
  for select to authenticated using (true);

drop policy if exists instrumentos_escrita on public.instrumentos;
create policy instrumentos_escrita on public.instrumentos
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

-- ----------------------------------------------------------- conteúdo

drop policy if exists metodos_leitura on public.metodos;
create policy metodos_leitura on public.metodos
  for select to authenticated
  using (publicado or public.tem_painel());

drop policy if exists metodos_escrita on public.metodos;
create policy metodos_escrita on public.metodos
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists fases_leitura on public.fases;
create policy fases_leitura on public.fases
  for select to authenticated
  using (public.metodo_visivel(metodo_id));

drop policy if exists fases_escrita on public.fases;
create policy fases_escrita on public.fases
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists licoes_leitura on public.licoes;
create policy licoes_leitura on public.licoes
  for select to authenticated
  using (public.fase_visivel(fase_id));

drop policy if exists licoes_escrita on public.licoes;
create policy licoes_escrita on public.licoes
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

-- A questão em rascunho é trabalho do painel: o aluno só recebe as
-- publicadas, que são as que podem cair na prova.
drop policy if exists questoes_leitura on public.questoes;
create policy questoes_leitura on public.questoes
  for select to authenticated
  using (public.fase_visivel(fase_id) and (status = 'publicada' or public.tem_painel()));

drop policy if exists questoes_escrita on public.questoes;
create policy questoes_escrita on public.questoes
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists jogos_leitura on public.jogos;
create policy jogos_leitura on public.jogos
  for select to authenticated
  using (public.fase_visivel(fase_id));

drop policy if exists jogos_escrita on public.jogos;
create policy jogos_escrita on public.jogos
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

-- ------------------------------------------------------------- turmas

drop policy if exists turmas_leitura on public.turmas;
create policy turmas_leitura on public.turmas
  for select to authenticated using (true);

drop policy if exists turmas_escrita on public.turmas;
create policy turmas_escrita on public.turmas
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists turma_conteudos_leitura on public.turma_conteudos;
create policy turma_conteudos_leitura on public.turma_conteudos
  for select to authenticated using (true);

drop policy if exists turma_conteudos_escrita on public.turma_conteudos;
create policy turma_conteudos_escrita on public.turma_conteudos
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists turma_instrutores_leitura on public.turma_instrutores;
create policy turma_instrutores_leitura on public.turma_instrutores
  for select to authenticated using (true);

drop policy if exists turma_instrutores_escrita on public.turma_instrutores;
create policy turma_instrutores_escrita on public.turma_instrutores
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

-- O voto é do instrutor: ele insere e troca o próprio, e ninguém vota no
-- lugar dele. A gestão pode limpar votos de uma turma recolhida.
drop policy if exists turma_avaliacoes_leitura on public.turma_avaliacoes;
create policy turma_avaliacoes_leitura on public.turma_avaliacoes
  for select to authenticated using (true);

drop policy if exists turma_avaliacoes_voto on public.turma_avaliacoes;
create policy turma_avaliacoes_voto on public.turma_avaliacoes
  for insert to authenticated
  with check (instrutor_id = auth.uid());

drop policy if exists turma_avaliacoes_troca on public.turma_avaliacoes;
create policy turma_avaliacoes_troca on public.turma_avaliacoes
  for update to authenticated
  using (instrutor_id = auth.uid())
  with check (instrutor_id = auth.uid());

drop policy if exists turma_avaliacoes_limpeza on public.turma_avaliacoes;
create policy turma_avaliacoes_limpeza on public.turma_avaliacoes
  for delete to authenticated
  using (instrutor_id = auth.uid() or public.tem_gestao());

-- --------------------------------------------------- níveis e requisitos

drop policy if exists niveis_leitura on public.niveis;
create policy niveis_leitura on public.niveis
  for select to authenticated using (true);

drop policy if exists niveis_escrita on public.niveis;
create policy niveis_escrita on public.niveis
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists nivel_regras_leitura on public.nivel_regras;
create policy nivel_regras_leitura on public.nivel_regras
  for select to authenticated using (true);

drop policy if exists nivel_regras_escrita on public.nivel_regras;
create policy nivel_regras_escrita on public.nivel_regras
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists nivel_requisitos_leitura on public.nivel_requisitos;
create policy nivel_requisitos_leitura on public.nivel_requisitos
  for select to authenticated using (true);

drop policy if exists nivel_requisitos_escrita on public.nivel_requisitos;
create policy nivel_requisitos_escrita on public.nivel_requisitos
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

-- --------------------------------------------------------- matrículas

drop policy if exists matriculas_leitura on public.matriculas;
create policy matriculas_leitura on public.matriculas
  for select to authenticated
  using (aluno_id = auth.uid() or public.tem_painel());

drop policy if exists matriculas_escrita on public.matriculas;
create policy matriculas_escrita on public.matriculas
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

-- Histórico não se reescreve: só entra linha nova, e quem já passou por ali
-- consegue ler a própria evolução.
drop policy if exists matricula_historico_leitura on public.matricula_historico;
create policy matricula_historico_leitura on public.matricula_historico
  for select to authenticated
  using (aluno_id = auth.uid() or public.tem_painel());

drop policy if exists matricula_historico_insercao on public.matricula_historico;
create policy matricula_historico_insercao on public.matricula_historico
  for insert to authenticated
  with check (public.tem_gestao());

-- ------------------------------------------------- progresso do aluno

drop policy if exists progresso_leitura on public.progresso_fases;
create policy progresso_leitura on public.progresso_fases
  for select to authenticated
  using (aluno_id = auth.uid() or public.tem_painel());

drop policy if exists progresso_escrita on public.progresso_fases;
create policy progresso_escrita on public.progresso_fases
  for all to authenticated
  using (aluno_id = auth.uid()) with check (aluno_id = auth.uid());

drop policy if exists tentativas_leitura on public.tentativas;
create policy tentativas_leitura on public.tentativas
  for select to authenticated
  using (aluno_id = auth.uid() or public.tem_painel());

drop policy if exists tentativas_escrita on public.tentativas;
create policy tentativas_escrita on public.tentativas
  for all to authenticated
  using (aluno_id = auth.uid()) with check (aluno_id = auth.uid());

drop policy if exists questoes_usadas_leitura on public.questoes_usadas;
create policy questoes_usadas_leitura on public.questoes_usadas
  for select to authenticated
  using (aluno_id = auth.uid() or public.tem_painel());

drop policy if exists questoes_usadas_escrita on public.questoes_usadas;
create policy questoes_usadas_escrita on public.questoes_usadas
  for all to authenticated
  using (aluno_id = auth.uid()) with check (aluno_id = auth.uid());

drop policy if exists certificados_leitura on public.certificados;
create policy certificados_leitura on public.certificados
  for select to authenticated
  using (aluno_id = auth.uid() or public.tem_painel());

drop policy if exists certificados_escrita on public.certificados;
create policy certificados_escrita on public.certificados
  for all to authenticated
  using (aluno_id = auth.uid()) with check (aluno_id = auth.uid());

-- ---------------------------------------------------------- sugestões

drop policy if exists sugestoes_leitura on public.sugestoes;
create policy sugestoes_leitura on public.sugestoes
  for select to authenticated
  using (autor_id = auth.uid() or public.tem_painel());

drop policy if exists sugestoes_envio on public.sugestoes;
create policy sugestoes_envio on public.sugestoes
  for insert to authenticated
  with check (autor_id = auth.uid());

drop policy if exists sugestoes_resolucao on public.sugestoes;
create policy sugestoes_resolucao on public.sugestoes
  for update to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists sugestoes_exclusao on public.sugestoes;
create policy sugestoes_exclusao on public.sugestoes
  for delete to authenticated
  using (public.tem_gestao());

-- ------------------------------------------------------------- cursos

-- Curso é rascunho de conteúdo: fica inteiro dentro do painel até virar
-- método publicado.
drop policy if exists cursos_gestao on public.cursos;
create policy cursos_gestao on public.cursos
  for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

-- ---------------------------------------------------------- auditoria

-- Só entra e se lê: sem update e sem delete, nem para administrador. Uma
-- trilha que pode ser reescrita não serve de trilha.
drop policy if exists auditoria_registro on public.auditoria;
create policy auditoria_registro on public.auditoria
  for insert to authenticated
  with check (usuario_id = auth.uid() or usuario_id is null);

drop policy if exists auditoria_leitura on public.auditoria;
create policy auditoria_leitura on public.auditoria
  for select to authenticated
  using (public.tem_gestao());

-- >>>>>>>>>>>>>>>>>>>>>>>>>> migrations/0004_conteudo.sql

-- =====================================================================
-- Estudo Musical — MSA · conteúdo entre o app e o banco
-- =====================================================================
-- O app trabalha com um objeto só na memória: métodos com fases dentro,
-- fases com lições, questões e jogos dentro. O banco guarda isso normalizado,
-- em tabelas separadas. As duas funções aqui fazem a tradução nos dois
-- sentidos, para o app não precisar conhecer o desenho das tabelas.
--
-- Os dois lados não andam iguais de propósito:
--
--   baixar  é automático e vale para todo mundo — `meu_conteudo()` devolve
--           o que a pessoa tem direito de ver, e o app grava por cima.
--
--   publicar é ato deliberado do painel — `publicar_conteudo()` grava o que
--           está no aparelho por cima do que está no banco, REMOVIDOS
--           inclusive. É por isso que não roda sozinha a cada tecla digitada:
--           um aparelho desatualizado publicando no automático apagaria o
--           trabalho de quem cadastrou conteúdo do outro lado.
--
-- Sugestão de aluno e voto de instrutor andam só para cima, cada um pela sua
-- função, porque nascem fora do painel.
-- =====================================================================

-- ------------------------------------------------------------- baixar

create or replace function public.meu_conteudo()
returns jsonb
language sql
security invoker
set search_path = public
stable
as $$
  select jsonb_build_object(
    'versao', 2,
    'mostrarMsa', coalesce((select valor from public.configuracoes where chave = 'mostrarMsa'), 'true'::jsonb),

    'metodos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id, 'nome', m.nome, 'instrumento', m.instrumento, 'descricao', m.descricao,
        'tipo', m.tipo, 'tonalidade', m.tonalidade, 'cor', m.cor, 'icone', m.icone,
        'publicado', m.publicado, 'criadoEm', m.criado_em,
        'fases', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', f.id, 'titulo', f.titulo, 'subtitulo', f.subtitulo, 'resumo', f.resumo,
            'paginas', f.paginas, 'icone', f.icone, 'pares', f.pares,
            'licoes', coalesce((
              select jsonb_agg(jsonb_build_object('titulo', l.titulo, 'pagina', l.pagina, 'corpo', l.corpo) order by l.ordem)
              from public.licoes l where l.fase_id = f.id
            ), '[]'::jsonb),
            'questoes', coalesce((
              select jsonb_agg(jsonb_build_object(
                'id', q.id, 'enunciado', q.enunciado, 'alternativas', q.alternativas,
                'correta', q.correta, 'explicacao', q.explicacao, 'status', q.status,
                'assinatura', q.assinatura, 'origem', q.origem
              ) order by q.criado_em)
              from public.questoes q where q.fase_id = f.id
            ), '[]'::jsonb),
            'jogos', coalesce((
              -- O jogo tem campos próprios de cada tipo (baralho, modo…), que
              -- moram em `config`; aqui voltam para o mesmo nível dos demais,
              -- que é como o app lê.
              select jsonb_agg(j.config || jsonb_build_object('tipo', j.tipo, 'titulo', j.titulo, 'descricao', j.descricao) order by j.ordem)
              from public.jogos j where j.fase_id = f.id
            ), '[]'::jsonb)
          ) order by f.ordem)
          from public.fases f where f.metodo_id = m.id
        ), '[]'::jsonb)
      ) order by m.criado_em)
      from public.metodos m
    ), '[]'::jsonb),

    'turmas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'nome', t.nome, 'instrumento', t.instrumento, 'status', t.status,
        'criadaEm', t.criada_em, 'enviadaEm', t.enviada_em, 'liberadaEm', t.liberada_em,
        'conteudos', coalesce((
          select jsonb_agg(c.fonte order by c.ordem) from public.turma_conteudos c where c.turma_id = t.id
        ), '[]'::jsonb),
        'instrutores', coalesce((
          select jsonb_agg(ti.instrutor_id) from public.turma_instrutores ti where ti.turma_id = t.id
        ), '[]'::jsonb),
        'niveis', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', n.id, 'nome', n.nome, 'operador', n.operador, 'modoLiberacao', n.modo_liberacao,
            'regras', coalesce((
              select jsonb_agg(jsonb_build_object(
                'fonte', r.fonte, 'de', r.de, 'ate', r.ate, 'paginas', r.paginas,
                'exigeAnterior', r.exige_anterior, 'operador', r.operador,
                'requisitos', coalesce((
                  select jsonb_agg(jsonb_build_object('fonte', x.fonte, 'percentualMinimo', x.percentual_minimo))
                  from public.nivel_requisitos x where x.nivel_id = n.id and x.regra_fonte = r.fonte
                ), '[]'::jsonb)
              ))
              from public.nivel_regras r where r.nivel_id = n.id
            ), '[]'::jsonb),
            'requisitos', coalesce((
              select jsonb_agg(jsonb_build_object('fonte', x.fonte, 'percentualMinimo', x.percentual_minimo))
              from public.nivel_requisitos x where x.nivel_id = n.id and x.regra_fonte is null
            ), '[]'::jsonb)
          ) order by n.ordem)
          from public.niveis n where n.turma_id = t.id
        ), '[]'::jsonb),
        'alunos', coalesce((
          select jsonb_agg(jsonb_build_object(
            -- `contaId` volta como o id que o aparelho conhece, quando a conta
            -- veio de uma instalação offline; senão, o id da conta na nuvem.
            'contaId', coalesce(p.conta_local, mt.aluno_id::text),
            'nivelId', mt.nivel_id, 'status', mt.status, 'desde', mt.desde, 'progresso', mt.progresso,
            'historicoNiveis', coalesce((
              select jsonb_agg(jsonb_build_object(
                'data', h.data, 'de', h.de, 'para', h.para, 'porQuem', h.por_quem,
                'motivo', h.motivo, 'observacao', h.observacao, 'progresso', h.progresso
              ) order by h.data)
              from public.matricula_historico h
              where h.turma_id = mt.turma_id and h.aluno_id = mt.aluno_id
            ), '[]'::jsonb)
          ))
          from public.matriculas mt join public.perfis p on p.id = mt.aluno_id
          where mt.turma_id = t.id
        ), '[]'::jsonb),
        'avaliacoes', coalesce((
          select jsonb_agg(jsonb_build_object(
            'instrutorId', a.instrutor_id, 'nome', p.nome, 'voto', a.voto,
            'comentario', a.comentario, 'data', a.data
          ))
          from public.turma_avaliacoes a join public.perfis p on p.id = a.instrutor_id
          where a.turma_id = t.id
        ), '[]'::jsonb)
      ) order by t.criada_em)
      from public.turmas t
    ), '[]'::jsonb),

    'sugestoes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'autor', s.autor_nome, 'perfil', s.perfil, 'metodoId', s.metodo_id,
        'faseId', s.fase_id, 'texto', s.texto, 'data', s.data, 'status', s.status,
        'resolvidaEm', s.resolvida_em
      ) order by s.data)
      from public.sugestoes s
    ), '[]'::jsonb)
  );
$$;

-- ----------------------------------------------------------- publicar

create or replace function public.publicar_conteudo(dados jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  metodo   jsonb;
  fase     jsonb;
  licao    jsonb;
  questao  jsonb;
  jogo     jsonb;
  turma    jsonb;
  nivel    jsonb;
  regra    jsonb;
  req      jsonb;
  aluno    jsonb;
  passo    jsonb;
  id_aluno uuid;
  i        integer;
  k        integer;
  avisos   text[] := '{}';
begin
  -- Duas recusas, e `is not true` em vez de `not`: assim a guarda vale mesmo
  -- para quem não tem linha em `perfis`, caso em que o papel viria NULL.
  if auth.uid() is null then
    raise exception 'Entre na sua conta para publicar conteúdo.';
  end if;
  if public.tem_gestao() is not true then
    raise exception 'Só o encarregado ou o administrador publica conteúdo.';
  end if;

  if dados ? 'mostrarMsa' then
    insert into public.configuracoes (chave, valor) values ('mostrarMsa', dados -> 'mostrarMsa')
    on conflict (chave) do update set valor = excluded.valor, atualizado_em = now();
  end if;

  -- ------------------------------------------------------------ métodos
  if dados ? 'metodos' then
    delete from public.metodos
     where id not in (select jsonb_array_elements(dados -> 'metodos') ->> 'id');

    i := 0;
    for metodo in select valor from jsonb_array_elements(dados -> 'metodos') as valor loop
      insert into public.metodos (id, nome, instrumento, descricao, tipo, tonalidade, cor, icone, publicado, criado_por, criado_em)
      values (
        metodo ->> 'id',
        coalesce(metodo ->> 'nome', 'Método'),
        coalesce(metodo ->> 'instrumento', 'Geral'),
        coalesce(metodo ->> 'descricao', ''),
        coalesce(metodo ->> 'tipo', 'metodo'),
        coalesce(metodo ->> 'tonalidade', ''),
        coalesce(nullif(metodo ->> 'cor', ''), '#2f9e6b'),
        coalesce(nullif(metodo ->> 'icone', ''), '🎵'),
        coalesce((metodo ->> 'publicado')::boolean, false),
        auth.uid(),
        coalesce(nullif(metodo ->> 'criadoEm', '')::timestamptz, now())
      )
      on conflict (id) do update set
        nome = excluded.nome, instrumento = excluded.instrumento, descricao = excluded.descricao,
        tipo = excluded.tipo, tonalidade = excluded.tonalidade, cor = excluded.cor,
        icone = excluded.icone, publicado = excluded.publicado;

      delete from public.fases
       where metodo_id = metodo ->> 'id'
         and id not in (select jsonb_array_elements(coalesce(metodo -> 'fases', '[]'::jsonb)) ->> 'id');

      k := 0;
      for fase in select valor from jsonb_array_elements(coalesce(metodo -> 'fases', '[]'::jsonb)) as valor loop
        insert into public.fases (id, metodo_id, ordem, titulo, subtitulo, resumo, paginas, icone, pares)
        values (
          fase ->> 'id', metodo ->> 'id', k,
          coalesce(fase ->> 'titulo', 'Fase'),
          coalesce(fase ->> 'subtitulo', ''),
          coalesce(fase ->> 'resumo', ''),
          coalesce(fase ->> 'paginas', ''),
          coalesce(nullif(fase ->> 'icone', ''), '🎼'),
          coalesce(fase -> 'pares', '[]'::jsonb)
        )
        on conflict (id) do update set
          metodo_id = excluded.metodo_id, ordem = excluded.ordem, titulo = excluded.titulo,
          subtitulo = excluded.subtitulo, resumo = excluded.resumo, paginas = excluded.paginas,
          icone = excluded.icone, pares = excluded.pares;

        -- Lição não tem id no app: a posição é a identidade dela. Por isso
        -- as lições da fase são regravadas inteiras, com id derivado da
        -- posição — estável entre uma publicação e outra.
        delete from public.licoes where fase_id = fase ->> 'id';
        i := 0;
        for licao in select valor from jsonb_array_elements(coalesce(fase -> 'licoes', '[]'::jsonb)) as valor loop
          insert into public.licoes (id, fase_id, ordem, titulo, pagina, corpo)
          values (
            'lic-' || (fase ->> 'id') || '-' || i, fase ->> 'id', i,
            coalesce(licao ->> 'titulo', 'Lição'),
            coalesce(licao ->> 'pagina', ''),
            coalesce(licao ->> 'corpo', '')
          );
          i := i + 1;
        end loop;

        -- Questão tem id próprio: some só a que foi apagada no painel.
        delete from public.questoes
         where fase_id = fase ->> 'id'
           and id not in (select jsonb_array_elements(coalesce(fase -> 'questoes', '[]'::jsonb)) ->> 'id');

        for questao in select valor from jsonb_array_elements(coalesce(fase -> 'questoes', '[]'::jsonb)) as valor loop
          insert into public.questoes (id, fase_id, enunciado, alternativas, correta, explicacao, status, assinatura, origem)
          values (
            questao ->> 'id', fase ->> 'id',
            coalesce(questao ->> 'enunciado', ''),
            coalesce(questao -> 'alternativas', '[]'::jsonb),
            coalesce(questao ->> 'correta', ''),
            coalesce(questao ->> 'explicacao', ''),
            coalesce(nullif(questao ->> 'status', ''), 'rascunho')::public.status_questao,
            coalesce(questao ->> 'assinatura', ''),
            coalesce(questao ->> 'origem', '')
          )
          on conflict (id) do update set
            fase_id = excluded.fase_id, enunciado = excluded.enunciado, alternativas = excluded.alternativas,
            correta = excluded.correta, explicacao = excluded.explicacao, status = excluded.status,
            assinatura = excluded.assinatura, origem = excluded.origem;
        end loop;

        -- Jogo também é posicional no app.
        delete from public.jogos where fase_id = fase ->> 'id';
        i := 0;
        for jogo in select valor from jsonb_array_elements(coalesce(fase -> 'jogos', '[]'::jsonb)) as valor loop
          insert into public.jogos (id, fase_id, ordem, tipo, titulo, descricao, config)
          values (
            'jog-' || (fase ->> 'id') || '-' || i, fase ->> 'id', i,
            coalesce(jogo ->> 'tipo', 'memoria'),
            coalesce(jogo ->> 'titulo', ''),
            coalesce(jogo ->> 'descricao', ''),
            jogo - 'tipo' - 'titulo' - 'descricao'
          );
          i := i + 1;
        end loop;

        k := k + 1;
      end loop;
    end loop;
  end if;

  -- ------------------------------------------------------------- turmas
  if dados ? 'turmas' then
    delete from public.turmas
     where id not in (select jsonb_array_elements(dados -> 'turmas') ->> 'id');

    for turma in select valor from jsonb_array_elements(dados -> 'turmas') as valor loop
      insert into public.turmas (id, nome, instrumento, status, criada_em, enviada_em, liberada_em, criada_por)
      values (
        turma ->> 'id',
        coalesce(turma ->> 'nome', 'Turma'),
        coalesce(turma ->> 'instrumento', ''),
        coalesce(nullif(turma ->> 'status', ''), 'rascunho')::public.status_turma,
        coalesce(nullif(turma ->> 'criadaEm', '')::timestamptz, now()),
        nullif(turma ->> 'enviadaEm', '')::timestamptz,
        nullif(turma ->> 'liberadaEm', '')::timestamptz,
        auth.uid()
      )
      on conflict (id) do update set
        nome = excluded.nome, instrumento = excluded.instrumento, status = excluded.status,
        enviada_em = excluded.enviada_em, liberada_em = excluded.liberada_em;

      delete from public.turma_conteudos where turma_id = turma ->> 'id';
      i := 0;
      for passo in select valor from jsonb_array_elements(coalesce(turma -> 'conteudos', '[]'::jsonb)) as valor loop
        insert into public.turma_conteudos (turma_id, fonte, ordem)
        values (turma ->> 'id', passo #>> '{}', i)
        on conflict (turma_id, fonte) do update set ordem = excluded.ordem;
        i := i + 1;
      end loop;

      delete from public.niveis
       where turma_id = turma ->> 'id'
         and id not in (select jsonb_array_elements(coalesce(turma -> 'niveis', '[]'::jsonb)) ->> 'id');

      k := 0;
      for nivel in select valor from jsonb_array_elements(coalesce(turma -> 'niveis', '[]'::jsonb)) as valor loop
        insert into public.niveis (id, turma_id, nome, ordem, operador, modo_liberacao)
        values (
          nivel ->> 'id', turma ->> 'id',
          coalesce(nivel ->> 'nome', 'Nível'), k,
          coalesce(nullif(nivel ->> 'operador', ''), 'TODOS')::public.operador_requisito,
          coalesce(nullif(nivel ->> 'modoLiberacao', ''), 'automatico')::public.modo_liberacao
        )
        on conflict (id) do update set
          turma_id = excluded.turma_id, nome = excluded.nome, ordem = excluded.ordem,
          operador = excluded.operador, modo_liberacao = excluded.modo_liberacao;

        -- Requisitos e regras são reescritos juntos: o apagar em cascata das
        -- regras leva os requisitos daquela regra, e os requisitos de entrada
        -- no nível (regra_fonte nulo) saem logo abaixo.
        delete from public.nivel_regras where nivel_id = nivel ->> 'id';
        delete from public.nivel_requisitos where nivel_id = nivel ->> 'id' and regra_fonte is null;

        for regra in select valor from jsonb_array_elements(coalesce(nivel -> 'regras', '[]'::jsonb)) as valor loop
          insert into public.nivel_regras (nivel_id, fonte, de, ate, paginas, exige_anterior, operador)
          values (
            nivel ->> 'id', regra ->> 'fonte',
            greatest(1, coalesce((regra ->> 'de')::integer, 1)),
            greatest(1, coalesce((regra ->> 'ate')::integer, 1)),
            coalesce(regra ->> 'paginas', ''),
            coalesce((regra ->> 'exigeAnterior')::boolean, false),
            coalesce(nullif(regra ->> 'operador', ''), 'TODOS')::public.operador_requisito
          )
          on conflict (nivel_id, fonte) do update set
            de = excluded.de, ate = excluded.ate, paginas = excluded.paginas,
            exige_anterior = excluded.exige_anterior, operador = excluded.operador;

          for req in select valor from jsonb_array_elements(coalesce(regra -> 'requisitos', '[]'::jsonb)) as valor loop
            insert into public.nivel_requisitos (nivel_id, regra_fonte, fonte, percentual_minimo)
            values (nivel ->> 'id', regra ->> 'fonte', req ->> 'fonte',
                    least(100, greatest(0, coalesce((req ->> 'percentualMinimo')::numeric, 0))));
          end loop;
        end loop;

        for req in select valor from jsonb_array_elements(coalesce(nivel -> 'requisitos', '[]'::jsonb)) as valor loop
          insert into public.nivel_requisitos (nivel_id, regra_fonte, fonte, percentual_minimo)
          values (nivel ->> 'id', null, req ->> 'fonte',
                  least(100, greatest(0, coalesce((req ->> 'percentualMinimo')::numeric, 0))));
        end loop;

        k := k + 1;
      end loop;

      -- ------------------------------------------------------ matrículas
      for aluno in select valor from jsonb_array_elements(coalesce(turma -> 'alunos', '[]'::jsonb)) as valor loop
        -- O aparelho conhece o aluno pelo id local; a nuvem, pelo id da conta.
        -- `conta_local` é a ponte entre os dois.
        select id into id_aluno from public.perfis
         where conta_local = aluno ->> 'contaId'
            or id::text = aluno ->> 'contaId'
         limit 1;

        if id_aluno is null then
          avisos := avisos || format('Matrícula sem conta na nuvem: %s', aluno ->> 'contaId');
          continue;
        end if;

        insert into public.matriculas (turma_id, aluno_id, nivel_id, status, desde, progresso)
        values (
          turma ->> 'id', id_aluno,
          nullif(aluno ->> 'nivelId', ''),
          coalesce(nullif(aluno ->> 'status', ''), 'ativo')::public.status_matricula,
          coalesce(nullif(aluno ->> 'desde', '')::timestamptz, now()),
          coalesce(aluno -> 'progresso', '{}'::jsonb)
        )
        on conflict (turma_id, aluno_id) do update set
          nivel_id = excluded.nivel_id, status = excluded.status, progresso = excluded.progresso;

        -- Histórico só cresce: entra a promoção que ainda não estava lá.
        for passo in select valor from jsonb_array_elements(coalesce(aluno -> 'historicoNiveis', '[]'::jsonb)) as valor loop
          insert into public.matricula_historico (turma_id, aluno_id, data, de, para, por_quem, motivo, observacao, progresso)
          select turma ->> 'id', id_aluno,
                 coalesce(nullif(passo ->> 'data', '')::timestamptz, now()),
                 coalesce(passo ->> 'de', ''), coalesce(passo ->> 'para', ''),
                 coalesce(passo ->> 'porQuem', 'sistema'), coalesce(passo ->> 'motivo', ''),
                 coalesce(passo ->> 'observacao', ''), coalesce(passo -> 'progresso', '{}'::jsonb)
          where not exists (
            select 1 from public.matricula_historico h
             where h.turma_id = turma ->> 'id' and h.aluno_id = id_aluno
               and h.data = coalesce(nullif(passo ->> 'data', '')::timestamptz, now())
          );
        end loop;
      end loop;

      delete from public.matriculas m
       where m.turma_id = turma ->> 'id'
         and not exists (
           select 1
             from jsonb_array_elements(coalesce(turma -> 'alunos', '[]'::jsonb)) as a
             join public.perfis p
               on p.conta_local = a.value ->> 'contaId' or p.id::text = a.value ->> 'contaId'
            where p.id = m.aluno_id
         );
    end loop;
  end if;

  -- Sugestão e voto sobem pelas funções próprias; aqui só o desfecho da
  -- sugestão, que é decisão do painel.
  if dados ? 'sugestoes' then
    for passo in select valor from jsonb_array_elements(dados -> 'sugestoes') as valor loop
      update public.sugestoes
         set status = coalesce(nullif(passo ->> 'status', ''), 'aberta')::public.status_sugestao,
             resolvida_em = nullif(passo ->> 'resolvidaEm', '')::timestamptz
       where id = passo ->> 'id';
    end loop;
  end if;

  return public.meu_conteudo() || jsonb_build_object('avisos', to_jsonb(avisos));
end;
$$;

-- --------------------------------------------------- o que sobe de baixo

-- A sugestão nasce com quem escreveu; nem o painel inventa sugestão no nome
-- de outra pessoa.
create or replace function public.enviar_sugestao(texto text, metodo_id text default null, fase_id text default null)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  eu uuid := auth.uid();
  novo_id text;
begin
  if eu is null then
    raise exception 'Entre na sua conta para enviar uma sugestão.';
  end if;
  if coalesce(trim(texto), '') = '' then
    raise exception 'Escreva a sugestão.';
  end if;

  novo_id := 'sug-' || md5(eu::text || '|' || texto || '|' || clock_timestamp()::text);

  insert into public.sugestoes (id, autor_id, autor_nome, perfil, metodo_id, fase_id, texto)
  select novo_id, eu, p.nome, p.perfil, metodo_id, fase_id, trim(texto)
    from public.perfis p where p.id = eu;

  return jsonb_build_object('ok', true, 'id', novo_id);
end;
$$;

-- O voto do instrutor na turma. Um voto por instrutor: votar de novo troca o
-- anterior, como no app.
create or replace function public.votar_turma(id_turma text, voto public.voto_avaliacao, comentario text default '')
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  eu uuid := auth.uid();
begin
  if eu is null then
    raise exception 'Entre na sua conta para avaliar.';
  end if;
  if voto = 'ajustes' and coalesce(trim(comentario), '') = '' then
    raise exception 'Diga o que precisa de ajuste.';
  end if;

  insert into public.turma_avaliacoes (turma_id, instrutor_id, voto, comentario, data)
  values (id_turma, eu, voto, coalesce(trim(comentario), ''), now())
  on conflict (turma_id, instrutor_id) do update set
    voto = excluded.voto, comentario = excluded.comentario, data = excluded.data;

  return jsonb_build_object('ok', true);
end;
$$;

-- >>>>>>>>>>>>>>>>>>>>>>>>>> migrations/0005_trava_nula.sql

-- =====================================================================
-- Estudo Musical — MSA · a tranca que NULL abria
-- =====================================================================
-- `papel_atual()` devolve NULL para quem não tem linha em `perfis` — um
-- visitante sem conta, ou uma conta do Auth cujo perfil não foi criado.
-- Com isso `tem_gestao()` também devolvia NULL, e na guarda da publicação
--
--     if not public.tem_gestao() then raise exception ...
--
-- o `not NULL` é NULL, que não é verdadeiro: o `if` não entrava e a função
-- seguia em frente. As políticas de acesso seguraram a gravação — para elas
-- NULL já vale como "não pode" —, então nada chegou a ser gravado. Mas a
-- tranca da função dependia de sorte, e tranca não se apoia em sorte.
--
-- Conserto na raiz: as duas funções de papel passam a devolver sempre
-- verdadeiro ou falso, nunca NULL. Com isso a guarda de `publicar_conteudo`
-- volta a disparar, sem precisar reescrever a função inteira.
-- =====================================================================

create or replace function public.tem_gestao()
returns boolean
language sql
stable
as $$
  select coalesce(public.papel_atual() in ('administrador', 'encarregado'), false);
$$;

create or replace function public.tem_painel()
returns boolean
language sql
stable
as $$
  select coalesce(public.papel_atual() in ('administrador', 'encarregado', 'instrutor'), false);
$$;
