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
