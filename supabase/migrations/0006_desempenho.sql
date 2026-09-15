-- =====================================================================
-- Estudo Musical — MSA · desempenho por assunto
-- =====================================================================
-- Até aqui a tentativa guardava só o placar: 7 de 10. Isso responde "como
-- foi a prova", mas não "em que o aluno tropeça" — e é essa a pergunta que
-- muda o que o instrutor faz na aula seguinte.
--
-- Cada questão do método embutido nasce de um gerador (`f6.ordem-dos-acidentes`,
-- `f2.ler-nota`…), e o gerador é o assunto. Guardando o acerto ou erro de cada
-- questão junto do assunto, dá para somar por tema e dizer onde está a
-- dificuldade.
--
-- A tabela é só de inserção, com chave vinda do aparelho: reenviar a mesma
-- tentativa não duplica nada, que é o mesmo princípio de `tentativas`.
-- =====================================================================

create table if not exists public.tentativa_itens (
  tentativa_id text not null references public.tentativas (id) on delete cascade,
  aluno_id     uuid not null references public.perfis (id) on delete cascade,
  indice       integer not null,
  assunto      text not null,
  certa        boolean not null,
  primary key (tentativa_id, indice)
);

-- O aluno_id fica repetido aqui de propósito: as políticas e a soma por
-- assunto ficam diretas, sem passar por `tentativas` a cada linha.
create index if not exists tentativa_itens_assunto_idx on public.tentativa_itens (assunto, certa);
create index if not exists tentativa_itens_aluno_idx on public.tentativa_itens (aluno_id);

alter table public.tentativa_itens enable row level security;

drop policy if exists tentativa_itens_leitura on public.tentativa_itens;
create policy tentativa_itens_leitura on public.tentativa_itens
  for select to authenticated
  using (aluno_id = auth.uid() or public.tem_painel());

drop policy if exists tentativa_itens_escrita on public.tentativa_itens;
create policy tentativa_itens_escrita on public.tentativa_itens
  for all to authenticated
  using (aluno_id = auth.uid()) with check (aluno_id = auth.uid());

-- ------------------------------------------------------------- subir

-- Recebe os itens das provas feitas no aparelho. Item de tentativa que não
-- existe no banco é ignorado em silêncio: a tentativa sobe primeiro, por
-- `sincronizar_progresso`, e só então os itens encontram onde se prender.
create or replace function public.sincronizar_itens(dados jsonb)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  eu uuid := auth.uid();
  entraram integer := 0;
begin
  if eu is null then
    raise exception 'Entre na sua conta para sincronizar.';
  end if;

  insert into public.tentativa_itens (tentativa_id, aluno_id, indice, assunto, certa)
  select t.id,
         eu,
         (item ->> 'indice')::integer,
         item ->> 'assunto',
         coalesce((item ->> 'certa')::boolean, false)
    from jsonb_array_elements(coalesce(dados, '[]'::jsonb)) as item
    join public.tentativas t
      on t.id = item ->> 'tentativaId' and t.aluno_id = eu
   where coalesce(item ->> 'assunto', '') <> ''
     and (item ->> 'indice') ~ '^[0-9]+$'
  on conflict (tentativa_id, indice) do nothing;

  get diagnostics entraram = row_count;
  return entraram;
end;
$$;

-- ------------------------------------------------------------ baixar

-- `meu_progresso` reescrita para devolver os itens junto de cada tentativa.
-- Sem isso o app perderia o detalhe na primeira sincronização, porque ele
-- grava por cima do que tinha com o que o servidor devolve.
--
-- `sincronizar_progresso` chama esta função pelo nome e passa a devolver os
-- itens sozinha, sem precisar ser reescrita.
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
            'total', t.total, 'nota', t.nota, 'aprovado', t.aprovado, 'semente', t.semente,
            'itens', coalesce((
              select jsonb_agg(jsonb_build_object('indice', it.indice, 'assunto', it.assunto, 'certa', it.certa)
                     order by it.indice)
              from public.tentativa_itens it
              where it.tentativa_id = t.id
            ), '[]'::jsonb)
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

-- ---------------------------------------------------------- relatório

-- Soma por assunto do que a pessoa tem direito de ver: o aluno enxerga o
-- próprio desempenho, quem tem painel enxerga o da turma inteira. Quem faz
-- esse corte é a política de acesso da tabela, não esta função.
create or replace function public.relatorio_assuntos()
returns table (assunto text, fase_ref text, certas bigint, erradas bigint, alunos bigint)
language sql
security invoker
set search_path = public
stable
as $$
  select i.assunto,
         min(t.fase_ref) as fase_ref,
         count(*) filter (where i.certa)     as certas,
         count(*) filter (where not i.certa) as erradas,
         count(distinct i.aluno_id)          as alunos
    from public.tentativa_itens i
    join public.tentativas t on t.id = i.tentativa_id
   group by i.assunto;
$$;

-- Placar por fase, para o resumo do relatório.
create or replace function public.relatorio_fases()
returns table (fase_ref text, tentativas bigint, acertos bigint, total bigint, alunos bigint)
language sql
security invoker
set search_path = public
stable
as $$
  select t.fase_ref,
         count(*)                   as tentativas,
         coalesce(sum(t.acertos), 0) as acertos,
         coalesce(sum(t.total), 0)   as total,
         count(distinct t.aluno_id)  as alunos
    from public.tentativas t
   group by t.fase_ref;
$$;
