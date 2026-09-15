-- =====================================================================
-- MSAapp Violino · 0003 · turmas, avaliação, desempenho e acompanhamento
-- =====================================================================
-- O que faz a diferença aqui é `respostas`: uma linha por questão
-- respondida, não só a nota da prova. Sem isso não há como dizer em que o
-- aluno tropeça, qual erro se repete e se ele está evoluindo — que são as
-- perguntas que o projeto quer ver respondidas.
-- =====================================================================

do $$ begin create type public.status_turma as enum
  ('RASCUNHO','ATIVA','ENCERRADA');
exception when duplicate_object then null; end $$;

do $$ begin create type public.status_matricula as enum
  ('ATIVO','TRANSFERIDO','DESLIGADO');
exception when duplicate_object then null; end $$;

do $$ begin create type public.modo_liberacao as enum ('SEQUENCIAL','MANUAL');
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------------- turmas

create table if not exists public.turmas (
  id             text primary key,
  nome           text not null,
  curso_id       text references public.cursos (id) on delete set null,
  nivel          text not null default '',
  encarregado_id uuid references public.usuarios (id) on delete set null,
  data_inicio    date,
  data_fim       date,
  status         public.status_turma not null default 'RASCUNHO',
  liberacao      public.modo_liberacao not null default 'SEQUENCIAL',
  criada_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now(),
  constraint periodo_valido check (data_fim is null or data_inicio is null or data_fim >= data_inicio)
);

drop trigger if exists turmas_atualizacao on public.turmas;
create trigger turmas_atualizacao before update on public.turmas
  for each row execute function public.marcar_atualizacao();

create table if not exists public.turma_instrutores (
  turma_id     text not null references public.turmas (id) on delete cascade,
  instrutor_id uuid not null references public.usuarios (id) on delete cascade,
  desde        timestamptz not null default now(),
  primary key (turma_id, instrutor_id)
);

-- Transferir não apaga: a matrícula antiga vira TRANSFERIDO e aponta para
-- onde o aluno foi. O histórico de quem passou pela turma fica de pé.
create table if not exists public.matriculas (
  turma_id       text not null references public.turmas (id) on delete cascade,
  aluno_id       uuid not null references public.usuarios (id) on delete cascade,
  status         public.status_matricula not null default 'ATIVO',
  desde          timestamptz not null default now(),
  ate            timestamptz,
  transferido_para text references public.turmas (id) on delete set null,
  observacao     text not null default '',
  primary key (turma_id, aluno_id)
);
create index if not exists matriculas_aluno_idx on public.matriculas (aluno_id, status);

-- Quem enxerga o desempenho de quem. Instrutor vê o aluno de turma sua;
-- encarregado e administrador veem todos.
create or replace function public.acompanha_aluno(id_aluno uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select case
    when auth.uid() = id_aluno then true
    when public.tem_gestao() then true
    when public.papel_atual() = 'INSTRUTOR' then exists (
      select 1 from public.matriculas m
      join public.turma_instrutores ti on ti.turma_id = m.turma_id
      where m.aluno_id = id_aluno and ti.instrutor_id = auth.uid() and m.status = 'ATIVO')
    else false end;
$$;

-- Liberação de conteúdo por turma: sequencial por padrão, com abertura
-- manual pelo encarregado quando ele quiser adiantar alguém.
create table if not exists public.liberacoes (
  turma_id    text not null references public.turmas (id) on delete cascade,
  fase_id     text not null references public.fases (id) on delete cascade,
  aluno_id    uuid references public.usuarios (id) on delete cascade,
  liberada    boolean not null default true,
  motivo      text not null default '',
  liberada_em timestamptz not null default now(),
  liberada_por uuid references public.usuarios (id) on delete set null,
  primary key (turma_id, fase_id, aluno_id)
);

-- ---------------------------------------------------------- avaliação

do $$ begin create type public.status_avaliacao as enum
  ('EM_ANDAMENTO','FINALIZADA','ABANDONADA');
exception when duplicate_object then null; end $$;

-- `composicao` guarda a mistura pedida pelo projeto, por exemplo
-- {"MSA":40,"METODO_VIOLINO":40,"HINARIO":20}. É configurável pelo
-- encarregado, e fica gravada na prova para a correção continuar
-- explicável meses depois.
create table if not exists public.modelos_avaliacao (
  id           text primary key,
  nome         text not null,
  turma_id     text references public.turmas (id) on delete cascade,
  fase_id      text references public.fases (id) on delete set null,
  composicao   jsonb not null default '{"MSA":100}'::jsonb,
  questoes     integer not null default 10 check (questoes between 1 and 100),
  nota_minima  smallint not null default 70 check (nota_minima between 0 and 100),
  criado_por   uuid references public.usuarios (id) on delete set null,
  criado_em    timestamptz not null default now()
);

create table if not exists public.avaliacoes (
  id            text primary key,
  modelo_id     text references public.modelos_avaliacao (id) on delete set null,
  aluno_id      uuid not null references public.usuarios (id) on delete cascade,
  turma_id      text references public.turmas (id) on delete set null,
  fase_id       text references public.fases (id) on delete set null,
  semente       bigint,
  status        public.status_avaliacao not null default 'EM_ANDAMENTO',
  iniciada_em   timestamptz not null default now(),
  finalizada_em timestamptz,
  acertos       integer not null default 0,
  total         integer not null default 0,
  nota          smallint not null default 0 check (nota between 0 and 100),
  aprovado      boolean not null default false,
  constraint acertos_cabem check (acertos <= total)
);
create index if not exists avaliacoes_aluno_idx on public.avaliacoes (aluno_id, iniciada_em desc);

-- Uma linha por questão respondida. É daqui que sai todo o resto.
create table if not exists public.respostas (
  id           text primary key,
  avaliacao_id text references public.avaliacoes (id) on delete cascade,
  aluno_id     uuid not null references public.usuarios (id) on delete cascade,
  questao_id   text references public.questoes (id) on delete set null,
  assinatura   text not null default '',
  gerador_id   text not null default '',
  fonte_id     text references public.fontes (id),
  fase         integer,
  modulo_id    text,
  dificuldade  smallint,
  habilidade   public.habilidade,
  resposta     text not null default '',
  correta      boolean not null,
  tempo_ms     integer check (tempo_ms is null or tempo_ms >= 0),
  data         timestamptz not null default now()
);
create index if not exists respostas_aluno_idx on public.respostas (aluno_id, data desc);
create index if not exists respostas_assunto_idx on public.respostas (gerador_id, correta);
create index if not exists respostas_fonte_idx on public.respostas (fonte_id, fase);

-- Não repetição: assinatura já usada sai do sorteio seguinte.
create table if not exists public.questoes_usadas (
  aluno_id   uuid not null references public.usuarios (id) on delete cascade,
  escopo     text not null,
  assinatura text not null,
  usada_em   timestamptz not null default now(),
  primary key (aluno_id, escopo, assinatura)
);

-- ------------------------------------------------------------- vídeos

do $$ begin create type public.status_video as enum
  ('ENVIADO','EM_ANALISE','APROVADO','REGRAVAR');
exception when duplicate_object then null; end $$;

create table if not exists public.videos (
  id          text primary key,
  aluno_id    uuid not null references public.usuarios (id) on delete cascade,
  contexto    text not null default 'LICAO',
  contexto_id text not null default '',
  titulo      text not null default '',
  descricao   text not null default '',
  pergunta    text not null default '',
  arquivo     text not null,
  status      public.status_video not null default 'ENVIADO',
  enviado_em  timestamptz not null default now()
);
create index if not exists videos_aluno_idx on public.videos (aluno_id, enviado_em desc);
create index if not exists videos_status_idx on public.videos (status, enviado_em);

create table if not exists public.criterios_video (
  id     text primary key,
  nome   text not null,
  ordem  integer not null default 0,
  ativo  boolean not null default true
);
insert into public.criterios_video (id, nome, ordem) values
  ('postura','Postura',1), ('arco','Arco',2), ('esquerda','Mão esquerda',3),
  ('afinacao','Afinação',4), ('ritmo','Ritmo',5), ('leitura','Leitura',6),
  ('execucao','Execução',7)
on conflict (id) do nothing;

create table if not exists public.video_avaliacoes (
  video_id     text not null references public.videos (id) on delete cascade,
  criterio_id  text not null references public.criterios_video (id),
  instrutor_id uuid not null references public.usuarios (id) on delete cascade,
  nota         smallint not null check (nota between 0 and 10),
  comentario   text not null default '',
  data         timestamptz not null default now(),
  primary key (video_id, criterio_id, instrutor_id)
);

-- --------------------------------------------- perguntas ao instrutor

create table if not exists public.perguntas (
  id           text primary key,
  aluno_id     uuid not null references public.usuarios (id) on delete cascade,
  instrutor_id uuid references public.usuarios (id) on delete set null,
  tipo         text not null default 'TEXTO',
  conteudo     text not null default '',
  anexo        text not null default '',
  licao_id     text references public.licoes (id) on delete set null,
  contexto_id  text not null default '',
  enviada_em   timestamptz not null default now(),
  resposta     text not null default '',
  respondida_em timestamptz,
  constraint tem_o_que_perguntar check (length(trim(conteudo)) > 0 or length(trim(anexo)) > 0)
);
create index if not exists perguntas_aluno_idx on public.perguntas (aluno_id, enviada_em desc);
create index if not exists perguntas_abertas_idx on public.perguntas (respondida_em) where respondida_em is null;

-- ------------------------------------------ medalhas e certificados

create table if not exists public.medalhas (
  id        text primary key,
  nome      text not null,
  descricao text not null default '',
  ordem     integer not null default 0,
  -- Critério objetivo, legível por máquina. Exemplo:
  -- {"tipo":"aproveitamento_minimo","fonte":"MSA","valor":85,"provas":3}
  criterio  jsonb not null default '{}'::jsonb
);
insert into public.medalhas (id, nome, descricao, ordem, criterio) values
  ('bronze','Bronze','Primeira fase concluída',1,'{"tipo":"fases_aprovadas","valor":1}'),
  ('prata','Prata','Metade da trilha concluída',2,'{"tipo":"fases_aprovadas","valor":5}'),
  ('ouro','Ouro','Trilha concluída',3,'{"tipo":"fases_aprovadas","valor":10}'),
  ('mestre_msa','Mestre MSA','85% ou mais nas avaliações do MSA',4,'{"tipo":"aproveitamento_minimo","fonte":"MSA","valor":85,"provas":3}'),
  ('mestre_violino','Mestre do Violino','85% ou mais no método de violino',5,'{"tipo":"aproveitamento_minimo","fonte":"METODO_VIOLINO","valor":85,"provas":3}'),
  ('mestre_hinario','Mestre do Hinário','85% ou mais no hinário',6,'{"tipo":"aproveitamento_minimo","fonte":"HINARIO","valor":85,"provas":3}'),
  ('musico_formacao','Músico em Formação','Vídeo aprovado pelo instrutor',7,'{"tipo":"videos_aprovados","valor":1}')
on conflict (id) do nothing;

create table if not exists public.aluno_medalhas (
  aluno_id    uuid not null references public.usuarios (id) on delete cascade,
  medalha_id  text not null references public.medalhas (id) on delete cascade,
  conquistada_em timestamptz not null default now(),
  evidencia   jsonb not null default '{}'::jsonb,
  primary key (aluno_id, medalha_id)
);

create table if not exists public.certificados (
  id         text primary key,
  aluno_id   uuid not null references public.usuarios (id) on delete cascade,
  escopo     text not null,
  escopo_id  text not null default '',
  nome       text not null,
  instrumento text not null default 'violino',
  etapa      text not null default '',
  nota       smallint check (nota between 0 and 100),
  medalha_id text references public.medalhas (id) on delete set null,
  data       timestamptz not null default now(),
  codigo     text not null unique
);
create index if not exists certificados_aluno_idx on public.certificados (aluno_id, data desc);
