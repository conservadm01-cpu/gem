-- =====================================================================
-- MSAapp Violino · 0002 · conteúdo, matriz, hinário e método
-- =====================================================================
-- CURSO → FASE → MÓDULO → LIÇÃO → ATIVIDADE → QUESTÃO, com o módulo
-- amarrado à fonte de onde veio. Toda linha de conteúdo carrega fonte e
-- página: é a regra de ouro nº 2, "toda questão deve possuir referência",
-- levada ao nível do banco em vez de ficar só na intenção.
--
-- Alterar não sobrescreve: um gatilho guarda a linha anterior inteira em
-- `conteudo_versoes` e sobe o número da versão.
-- =====================================================================

do $$ begin create type public.status_conteudo as enum
  ('RASCUNHO','TESTE','APROVADO','PUBLICADO','ARQUIVADO');
exception when duplicate_object then null; end $$;

do $$ begin create type public.habilidade as enum
  ('MEMORIZACAO','COMPREENSAO','APLICACAO','ANALISE','EXECUCAO');
exception when duplicate_object then null; end $$;

do $$ begin create type public.tipo_questao as enum (
  'MULTIPLA_ESCOLHA','VERDADEIRO_FALSO','ASSOCIACAO','ORDENAR','ARRASTAR',
  'IDENT_NOTA','IDENT_FIGURA','IDENT_COMPASSO','IDENT_ARMADURA',
  'IDENT_CORDA','IDENT_DEDO','IDENT_ARCADA','IDENT_ERRO',
  'AUDIO','IMAGEM','VIDEO','RESPOSTA_ABERTA');
exception when duplicate_object then null; end $$;

do $$ begin create type public.tipo_atividade as enum
  ('LICAO','EXERCICIO','JOGO','AVALIACAO','DESAFIO','GRAVACAO');
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------- versionamento

create table if not exists public.conteudo_versoes (
  id          bigint generated always as identity primary key,
  tabela      text not null,
  registro_id text not null,
  versao      integer not null,
  dados       jsonb not null,
  alterado_por uuid references public.usuarios (id) on delete set null,
  alterado_em timestamptz not null default now()
);
create index if not exists conteudo_versoes_idx on public.conteudo_versoes (tabela, registro_id, versao desc);

-- Guarda a linha como ela estava antes e sobe a versão. Serve para qualquer
-- tabela que tenha `id`, `versao` e `alterado_por`.
create or replace function public.versionar()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if to_jsonb(new) - 'versao' - 'alterado_em' - 'alterado_por'
     is distinct from to_jsonb(old) - 'versao' - 'alterado_em' - 'alterado_por' then
    insert into public.conteudo_versoes (tabela, registro_id, versao, dados, alterado_por)
    values (tg_table_name, old.id::text, old.versao, to_jsonb(old), auth.uid());
    new.versao := old.versao + 1;
    new.alterado_em := now();
    new.alterado_por := auth.uid();
  end if;
  return new;
end; $$;

-- ------------------------------------------------------------- fontes

create table if not exists public.fontes (
  id         text primary key,
  nome       text not null,
  edicao     text not null default '',
  observacao text not null default ''
);

insert into public.fontes (id, nome, edicao, observacao) values
  ('MSA','Método Simplificado de Aprendizagem Musical','1ª edição, dez/2022',
   'Congregação Cristã no Brasil. Currículo derivado com referência de página.'),
  ('METODO_VIOLINO','Método de Violino','Violino Schmoll CCB',
   'PDF escaneado de 81 páginas; conferir elementos gráficos no original. VALIDAÇÃO NECESSÁRIA — o original ainda não foi recebido; só a camada textual auxiliar.'),
  ('HINARIO','Hinário CCB nº 5','Livro número 5',
   'Índice e regras extraídos. A partitura recebida é a edição de órgão; falta a de cordas.')
on conflict (id) do nothing;

-- ---------------------------------------------- curso, fase e módulo

create table if not exists public.cursos (
  id          text primary key,
  nome        text not null,
  instrumento text not null default 'violino',
  descricao   text not null default '',
  status      public.status_conteudo not null default 'RASCUNHO',
  versao      integer not null default 1,
  criado_por  uuid references public.usuarios (id) on delete set null,
  criado_em   timestamptz not null default now(),
  alterado_por uuid references public.usuarios (id) on delete set null,
  alterado_em timestamptz not null default now(),
  constraint so_violino check (instrumento = 'violino')
);

create table if not exists public.fases (
  id        text primary key,
  curso_id  text not null references public.cursos (id) on delete cascade,
  numero    integer not null,
  titulo    text not null,
  subtitulo text not null default '',
  resumo    text not null default '',
  status    public.status_conteudo not null default 'RASCUNHO',
  versao    integer not null default 1,
  criado_por uuid references public.usuarios (id) on delete set null,
  criado_em timestamptz not null default now(),
  alterado_por uuid references public.usuarios (id) on delete set null,
  alterado_em timestamptz not null default now(),
  unique (curso_id, numero)
);

create table if not exists public.modulos (
  id       text primary key,
  fase_id  text not null references public.fases (id) on delete cascade,
  fonte_id text not null references public.fontes (id),
  ordem    integer not null default 0,
  titulo   text not null,
  paginas  text not null default '',
  status   public.status_conteudo not null default 'RASCUNHO',
  versao   integer not null default 1,
  criado_por uuid references public.usuarios (id) on delete set null,
  criado_em timestamptz not null default now(),
  alterado_por uuid references public.usuarios (id) on delete set null,
  alterado_em timestamptz not null default now()
);
create index if not exists modulos_fase_idx on public.modulos (fase_id, ordem);

create table if not exists public.licoes (
  id        text primary key,
  modulo_id text not null references public.modulos (id) on delete cascade,
  ordem     integer not null default 0,
  titulo    text not null,
  pagina    text not null default '',
  corpo     text not null default '',
  observacao text not null default '',
  status    public.status_conteudo not null default 'RASCUNHO',
  versao    integer not null default 1,
  criado_por uuid references public.usuarios (id) on delete set null,
  criado_em timestamptz not null default now(),
  alterado_por uuid references public.usuarios (id) on delete set null,
  alterado_em timestamptz not null default now()
);
create index if not exists licoes_modulo_idx on public.licoes (modulo_id, ordem);

create table if not exists public.atividades (
  id        text primary key,
  modulo_id text not null references public.modulos (id) on delete cascade,
  licao_id  text references public.licoes (id) on delete set null,
  ordem     integer not null default 0,
  tipo      public.tipo_atividade not null,
  titulo    text not null default '',
  descricao text not null default '',
  config    jsonb not null default '{}'::jsonb,
  status    public.status_conteudo not null default 'RASCUNHO',
  versao    integer not null default 1,
  criado_por uuid references public.usuarios (id) on delete set null,
  criado_em timestamptz not null default now(),
  alterado_por uuid references public.usuarios (id) on delete set null,
  alterado_em timestamptz not null default now()
);
create index if not exists atividades_modulo_idx on public.atividades (modulo_id, ordem);

-- ----------------------------------------------------------- questões

-- `assinatura_unica` é o que impede a mesma pergunta de cair duas vezes para
-- o mesmo aluno: hash de conteúdo + variante + enunciado + alternativas +
-- dificuldade. Única por módulo, para a mesma pergunta não entrar duas vezes
-- no banco por descuido de importação.
create table if not exists public.questoes (
  id              text primary key,
  modulo_id       text not null references public.modulos (id) on delete cascade,
  atividade_id    text references public.atividades (id) on delete set null,
  fonte_id        text not null references public.fontes (id),
  referencia      text not null,
  tipo            public.tipo_questao not null default 'MULTIPLA_ESCOLHA',
  enunciado       text not null,
  enunciado_html  text not null default '',
  alternativas    jsonb not null default '[]'::jsonb,
  resposta        text not null,
  explicacao      text not null default '',
  dificuldade     smallint not null default 1 check (dificuldade between 1 and 5),
  habilidade      public.habilidade not null default 'COMPREENSAO',
  tags            text[] not null default '{}',
  assinatura_unica text not null,
  gerador_id      text not null default '',
  status          public.status_conteudo not null default 'RASCUNHO',
  versao          integer not null default 1,
  criado_por      uuid references public.usuarios (id) on delete set null,
  criado_em       timestamptz not null default now(),
  alterado_por    uuid references public.usuarios (id) on delete set null,
  alterado_em     timestamptz not null default now(),
  constraint referencia_obrigatoria check (length(trim(referencia)) > 0)
);
create unique index if not exists questoes_assinatura_idx on public.questoes (modulo_id, assinatura_unica);
create index if not exists questoes_busca_idx on public.questoes (modulo_id, status, dificuldade, habilidade);
create index if not exists questoes_gerador_idx on public.questoes (gerador_id);

do $$
declare t text;
begin
  foreach t in array array['cursos','fases','modulos','licoes','atividades','questoes'] loop
    execute format('drop trigger if exists %I_versiona on public.%I', t, t);
    execute format('create trigger %I_versiona before update on public.%I
                    for each row execute function public.versionar()', t, t);
  end loop;
end $$;

-- ------------------------------------------------------------- matriz

-- A matriz pedagógica pedida no projeto. Existe à parte do conteúdo porque é
-- o mapa de cobertura: serve para enxergar buracos (assunto sem questão,
-- habilidade sem atividade) antes de o aluno esbarrar neles.
create table if not exists public.matriz (
  id               text primary key,
  instrumento      text not null default 'violino',
  fonte_id         text not null references public.fontes (id),
  fase             integer,
  modulo           text not null default '',
  licao            text not null default '',
  assunto          text not null,
  subassunto       text not null default '',
  habilidade       public.habilidade,
  pagina           text not null default '',
  exercicio        text not null default '',
  dificuldade      smallint check (dificuldade between 1 and 5),
  tipo_atividade   public.tipo_atividade,
  tipo_questao     public.tipo_questao,
  pre_requisito    text not null default '',
  objetivo         text not null default '',
  tags             text[] not null default '{}',
  -- Marca o que é classificação do sistema e ainda não passou por revisão
  -- humana: habilidade e dificuldade não vêm das fontes.
  revisado         boolean not null default false,
  conferir_no_original boolean not null default false,
  observacao       text not null default ''
);
create index if not exists matriz_fonte_idx on public.matriz (fonte_id, fase);
create index if not exists matriz_assunto_idx on public.matriz (assunto);

-- ------------------------------------------------------------ hinário

do $$ begin create type public.tipo_hino as enum ('HINO','CORO');
exception when duplicate_object then null; end $$;

create table if not exists public.hinos (
  numero          integer not null,
  tipo            public.tipo_hino not null default 'HINO',
  nome            text not null,
  compositor      text not null default '',
  edicao          text not null default '',
  -- `armadura` é o que está impresso na partitura (quantos sustenidos ou
  -- bemóis). A tonalidade em si o hinário não escreve, então continua campo
  -- à parte, preenchido só depois de validada.
  armadura        text not null default '',
  tonalidade      text not null default '',
  compasso        text not null default '',
  andamento_min   integer,
  andamento_max   integer,
  andamento_figura text not null default '',
  -- Regra do próprio hinário: violino toca soprano, uma oitava acima.
  voz_violino     text not null default 'soprano',
  oitava_violino  text not null default 'uma oitava acima',
  tem_ritornello  boolean,
  tem_final       boolean,
  arcadas         jsonb not null default '[]'::jsonb,
  arquivo         text not null default '',
  pdf_pagina      integer,
  observacoes     text not null default '',
  status          public.status_conteudo not null default 'RASCUNHO',
  primary key (tipo, numero),
  constraint faixa_de_andamento check (andamento_max is null or andamento_min is null or andamento_max >= andamento_min)
);

-- As instruções de utilização, transcritas literalmente da fonte.
create table if not exists public.hinario_regras (
  id             text primary key,
  assunto        text not null,
  texto          text not null,
  pdf_pagina     integer,
  aplica_violino boolean not null default false
);

-- ------------------------------------------------- método de violino

-- Taxonomia de indexação do método, nas dez áreas do mapa pedagógico da
-- camada auxiliar. É índice de navegação, não conteúdo: a formulação de cada
-- lição só entra quando o método original chegar.
--
-- `[CONFERIR NO ORIGINAL]` é a marca pedida pela própria camada auxiliar,
-- para o que depende de partitura, desenho ou símbolo — que OCR de texto não
-- lê de forma confiável. Fica separada de VALIDAÇÃO NECESSÁRIA de propósito:
-- uma diz "existe no original, confira lá"; a outra, "ainda não temos fonte".
create table if not exists public.metodo_topicos (
  id         text primary key,
  ordem      integer not null default 0,
  area       text not null,
  titulo     text not null,
  indicadores text not null default '',
  pagina     text not null default '',
  exercicio  text not null default '',
  conferir_no_original boolean not null default true,
  status     public.status_conteudo not null default 'RASCUNHO',
  observacao text not null default 'VALIDAÇÃO NECESSÁRIA — aguardando o método de violino'
);

insert into public.metodo_topicos (id, ordem, area, titulo, indicadores) values
  ('mv.instrumento',  1,'Instrumento','Conhecimento do instrumento','Partes do violino; conhecimento do instrumento; manutenção.'),
  ('mv.arco',         2,'Arco','O arco','Partes do arco; pegada; movimentos; sinais e exercícios de arcada.'),
  ('mv.postura',      3,'Postura','Postura e posicionamento','Posição do corpo e posicionamento do violino para execução.'),
  ('mv.afinacao',     4,'Afinação','Afinação','Cordas soltas e procedimentos de afinação apresentados no método.'),
  ('mv.mao_esquerda', 5,'Mão esquerda','Mão esquerda','Posicionamento, colocação dos dedos e exercícios progressivos.'),
  ('mv.leitura',      6,'Leitura','Leitura aplicada ao violino','Exercícios associados à leitura musical aplicada ao violino.'),
  ('mv.escalas',      7,'Escalas','Escalas','Exercícios de escalas e progressão técnica.'),
  ('mv.posicoes',     8,'Posições','Posições','Conteúdo relacionado a posições, incluindo 3ª e 5ª posições.'),
  ('mv.tecnicas',     9,'Técnicas','Técnicas de arco','Staccato, martelato e saltellato.'),
  ('mv.harmonicos',  10,'Harmônicos','Harmônicos','Conteúdo específico sobre harmônicos.')
on conflict (id) do nothing;
