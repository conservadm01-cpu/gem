-- =====================================================================
-- MSAapp Violino · 0001 · identidade, permissões e auditoria
-- =====================================================================
-- Senha não mora aqui: fica no `auth.users` do Supabase, verificada pelo
-- servidor. Esta tabela é o cadastro que o sistema enxerga.
--
-- RBAC em duas camadas: a permissão vem do papel, e `usuario_permissoes`
-- abre exceção para uma pessoa sem mexer no papel dela. A verificação é do
-- lado do servidor, nas políticas de acesso — o frontend não decide nada.
-- =====================================================================

do $$ begin create type public.papel as enum
  ('ADMINISTRADOR','ENCARREGADO','INSTRUTOR','ALUNO');
exception when duplicate_object then null; end $$;

do $$ begin create type public.status_usuario as enum
  ('ATIVO','INATIVO','SUSPENSO');
exception when duplicate_object then null; end $$;

create or replace function public.marcar_atualizacao()
returns trigger language plpgsql as $$
begin new.atualizado_em := now(); return new; end; $$;

create table if not exists public.usuarios (
  id            uuid primary key references auth.users (id) on delete cascade,
  nome          text not null,
  email         text,
  telefone      text,
  login         text unique,
  perfil        public.papel not null default 'ALUNO',
  status        public.status_usuario not null default 'ATIVO',
  avatar_url    text,
  conta_local   text unique,
  criado_em     timestamptz not null default now(),
  ultimo_acesso timestamptz,
  atualizado_em timestamptz not null default now()
);
create index if not exists usuarios_perfil_idx on public.usuarios (perfil, status);

drop trigger if exists usuarios_atualizacao on public.usuarios;
create trigger usuarios_atualizacao before update on public.usuarios
  for each row execute function public.marcar_atualizacao();

-- ------------------------------------------------------------- RBAC

create table if not exists public.permissoes (
  codigo    text primary key,
  descricao text not null,
  grupo     text not null default 'geral'
);

-- O que cada papel pode por padrão.
create table if not exists public.perfil_permissoes (
  perfil          public.papel not null,
  permissao       text not null references public.permissoes (codigo) on delete cascade,
  primary key (perfil, permissao)
);

-- Exceção por pessoa: concede (true) ou revoga (false) sem mexer no papel.
create table if not exists public.usuario_permissoes (
  usuario_id  uuid not null references public.usuarios (id) on delete cascade,
  permissao   text not null references public.permissoes (codigo) on delete cascade,
  concedida   boolean not null default true,
  motivo      text not null default '',
  definida_em timestamptz not null default now(),
  primary key (usuario_id, permissao)
);

insert into public.permissoes (codigo, descricao, grupo) values
  ('sistema.administrar',  'Configurar o sistema, papéis e backup',        'sistema'),
  ('usuario.ler',          'Ver cadastros de usuários',                    'usuarios'),
  ('usuario.escrever',     'Criar e editar usuários',                      'usuarios'),
  ('usuario.promover',     'Mudar o papel de uma conta',                   'usuarios'),
  ('turma.ler',            'Ver turmas',                                   'turmas'),
  ('turma.escrever',       'Criar, editar e transferir alunos',            'turmas'),
  ('conteudo.ler',         'Ver conteúdo publicado',                       'conteudo'),
  ('conteudo.ler_rascunho','Ver conteúdo em rascunho e em teste',          'conteudo'),
  ('conteudo.escrever',    'Criar e editar conteúdo',                      'conteudo'),
  ('conteudo.aprovar',     'Aprovar conteúdo testado',                     'conteudo'),
  ('conteudo.publicar',    'Publicar conteúdo aprovado',                   'conteudo'),
  ('questao.gerar',        'Usar o gerador de questões',                   'conteudo'),
  ('avaliacao.montar',     'Montar avaliações e sua composição',           'avaliacao'),
  ('avaliacao.responder',  'Responder avaliações',                         'avaliacao'),
  ('desempenho.proprio',   'Ver o próprio desempenho',                     'desempenho'),
  ('desempenho.turma',     'Ver o desempenho dos alunos autorizados',      'desempenho'),
  ('desempenho.geral',     'Ver o desempenho de toda a obra',              'desempenho'),
  ('video.enviar',         'Enviar vídeo de execução',                     'video'),
  ('video.avaliar',        'Assistir e avaliar vídeos dos alunos',         'video'),
  ('pergunta.enviar',      'Perguntar ao instrutor',                       'pergunta'),
  ('pergunta.responder',   'Responder perguntas de alunos',                'pergunta'),
  ('log.ler',              'Ler a trilha de auditoria',                    'sistema'),
  ('backup.exportar',      'Exportar dados em JSON e CSV',                 'sistema')
on conflict (codigo) do nothing;

insert into public.perfil_permissoes (perfil, permissao)
select 'ADMINISTRADOR', codigo from public.permissoes
on conflict do nothing;

insert into public.perfil_permissoes (perfil, permissao) values
  ('ENCARREGADO','usuario.ler'),('ENCARREGADO','usuario.escrever'),
  ('ENCARREGADO','turma.ler'),('ENCARREGADO','turma.escrever'),
  ('ENCARREGADO','conteudo.ler'),('ENCARREGADO','conteudo.ler_rascunho'),
  ('ENCARREGADO','conteudo.escrever'),('ENCARREGADO','conteudo.aprovar'),
  ('ENCARREGADO','conteudo.publicar'),('ENCARREGADO','questao.gerar'),
  ('ENCARREGADO','avaliacao.montar'),('ENCARREGADO','desempenho.turma'),
  ('ENCARREGADO','desempenho.geral'),('ENCARREGADO','video.avaliar'),
  ('ENCARREGADO','pergunta.responder'),('ENCARREGADO','log.ler'),
  ('ENCARREGADO','backup.exportar'),
  ('INSTRUTOR','turma.ler'),('INSTRUTOR','conteudo.ler'),
  ('INSTRUTOR','conteudo.ler_rascunho'),('INSTRUTOR','avaliacao.montar'),
  ('INSTRUTOR','desempenho.turma'),('INSTRUTOR','video.avaliar'),
  ('INSTRUTOR','pergunta.responder'),('INSTRUTOR','usuario.ler'),
  ('ALUNO','conteudo.ler'),('ALUNO','avaliacao.responder'),
  ('ALUNO','desempenho.proprio'),('ALUNO','video.enviar'),
  ('ALUNO','pergunta.enviar')
on conflict do nothing;

-- --------------------------------------------------- quem está usando

create or replace function public.papel_atual()
returns public.papel language sql security definer set search_path = public stable
as $$ select perfil from public.usuarios where id = auth.uid() and status = 'ATIVO'; $$;

-- A permissão vem do papel, salvo exceção registrada para a pessoa. Nunca
-- devolve NULL: `not NULL` não é verdadeiro, e uma guarda escrita assim
-- deixaria passar quem não tem cadastro.
create or replace function public.tem_permissao(codigo text)
returns boolean language sql security definer set search_path = public stable
as $$
  select coalesce((
    select up.concedida
      from public.usuario_permissoes up
     where up.usuario_id = auth.uid() and up.permissao = codigo
  ), exists (
    select 1 from public.perfil_permissoes pp
     where pp.perfil = public.papel_atual() and pp.permissao = codigo
  ), false);
$$;

create or replace function public.eh_administrador() returns boolean
language sql stable as $$ select coalesce(public.papel_atual() = 'ADMINISTRADOR', false); $$;

create or replace function public.tem_painel() returns boolean
language sql stable as $$
  select coalesce(public.papel_atual() in ('ADMINISTRADOR','ENCARREGADO','INSTRUTOR'), false); $$;

create or replace function public.tem_gestao() returns boolean
language sql stable as $$
  select coalesce(public.papel_atual() in ('ADMINISTRADOR','ENCARREGADO'), false); $$;

-- --------------------------------------------------------- cadastro

-- O papel NUNCA vem do formulário de inscrição: quem se cadastra entra como
-- ALUNO e só um administrador promove. A primeira conta do sistema é a
-- exceção, para o painel não nascer trancado.
create or replace function public.criar_usuario_do_auth()
returns trigger language plpgsql security definer set search_path = public as $$
declare primeiro boolean;
begin
  select not exists (select 1 from public.usuarios) into primeiro;
  insert into public.usuarios (id, nome, email, login, perfil)
  values (new.id,
          coalesce(nullif(new.raw_user_meta_data ->> 'nome',''), split_part(new.email,'@',1)),
          new.email,
          nullif(new.raw_user_meta_data ->> 'login',''),
          case when primeiro then 'ADMINISTRADOR'::public.papel else 'ALUNO'::public.papel end)
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users
  for each row execute function public.criar_usuario_do_auth();

-- Promover é ato de administrador. A política trabalha por linha, então a
-- coluna `perfil` precisa desta trava à parte.
create or replace function public.proteger_papel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.perfil is distinct from old.perfil and not public.eh_administrador() then
    raise exception 'Só um administrador muda o papel de uma conta.';
  end if;
  return new;
end; $$;

drop trigger if exists usuarios_protege_papel on public.usuarios;
create trigger usuarios_protege_papel before update on public.usuarios
  for each row execute function public.proteger_papel();

-- -------------------------------------------------------- auditoria

do $$ begin create type public.acao_log as enum (
  'LOGIN','LOGIN_FALHO','LOGOUT',
  'CRIACAO_USUARIO','ALTERACAO_USUARIO','ALTERACAO_PERMISSAO',
  'CRIACAO_TURMA','ALTERACAO_TURMA',
  'CRIACAO_CONTEUDO','ALTERACAO_CONTEUDO','APROVACAO_CONTEUDO','PUBLICACAO_CONTEUDO',
  'QUESTAO_RESPONDIDA','AVALIACAO_INICIADA','AVALIACAO_FINALIZADA',
  'VIDEO_ENVIADO','VIDEO_AVALIADO','PERGUNTA_ENVIADA','RESPOSTA_INSTRUTOR',
  'MEDALHA_CONQUISTADA','MODULO_CONCLUIDO','CERTIFICADO_GERADO');
exception when duplicate_object then null; end $$;

-- Só entra e se lê. Sem update e sem delete, nem para administrador: uma
-- trilha que pode ser reescrita não serve de trilha.
create table if not exists public.logs (
  id          bigint generated always as identity primary key,
  usuario_id  uuid references public.usuarios (id) on delete set null,
  acao        public.acao_log not null,
  data_hora   timestamptz not null default now(),
  entidade    text not null default '',
  entidade_id text not null default '',
  resultado   text not null default 'OK',
  metadados   jsonb not null default '{}'::jsonb
);
create index if not exists logs_data_idx on public.logs (data_hora desc);
create index if not exists logs_usuario_idx on public.logs (usuario_id, data_hora desc);
create index if not exists logs_acao_idx on public.logs (acao, data_hora desc);

-- SECURITY DEFINER de propósito, por dois motivos.
--
-- Primeiro: quem registra não é quem lê. Só o papel com `log.ler` enxerga a
-- trilha, e `insert ... returning` no Postgres também exige política de
-- leitura — então um aluno registrando o próprio login esbarraria na política
-- de leitura e o log se perderia justamente para quem mais gera evento.
--
-- Segundo: não há como forjar autoria. A função nunca recebe um id de
-- usuário; ela grava `auth.uid()` e ponto. A única linha sem dono é a de
-- LOGIN_FALHO, que por definição acontece antes de haver sessão.
create or replace function public.registrar_log(
  p_acao public.acao_log, p_entidade text default '', p_entidade_id text default '',
  p_resultado text default 'OK', p_metadados jsonb default '{}'::jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare novo_id bigint;
begin
  if auth.uid() is null and p_acao <> 'LOGIN_FALHO' then
    raise exception 'Só uma tentativa de login sem sucesso pode ser registrada sem sessão.';
  end if;
  insert into public.logs (usuario_id, acao, entidade, entidade_id, resultado, metadados)
  values (auth.uid(), p_acao, coalesce(p_entidade,''), coalesce(p_entidade_id,''),
          coalesce(p_resultado,'OK'), coalesce(p_metadados,'{}'::jsonb))
  returning id into novo_id;
  return novo_id;
end; $$;
