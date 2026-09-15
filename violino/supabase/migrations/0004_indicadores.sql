-- =====================================================================
-- MSAapp Violino · 0004 · indicadores de desempenho
-- =====================================================================
-- As funções aqui existem para responder, com dado e não com impressão:
-- onde o aluno está, no que é bom, onde tropeça, qual erro se repete, o que
-- o instrutor deve trabalhar e se ele está pronto para avançar.
--
-- Todas são `security invoker`: o corte de quem enxerga quem é feito pelas
-- políticas de acesso de `respostas`, não por parâmetro — assim não existe
-- função que, chamada com o id certo, devolva o que a política negaria.
-- =====================================================================

do $$ begin create type public.nivel_dominio as enum
  ('DOMINIO','EM_DESENVOLVIMENTO','ATENCAO','NECESSITA_REFORCO','SEM_DADOS');
exception when duplicate_object then null; end $$;

-- A escala do projeto: 85+ domínio, 70–84 em desenvolvimento, 50–69 atenção,
-- abaixo de 50 reforço. Abaixo do mínimo de respostas não classifica: errar a
-- única questão de um assunto daria 0% e mandaria para reforço sem razão.
create or replace function public.classificar_dominio(acertos bigint, total bigint, minimo integer default 4)
returns public.nivel_dominio language sql immutable as $$
  select case
    when total is null or total < minimo then 'SEM_DADOS'::public.nivel_dominio
    when acertos::numeric * 100 / total >= 85 then 'DOMINIO'
    when acertos::numeric * 100 / total >= 70 then 'EM_DESENVOLVIMENTO'
    when acertos::numeric * 100 / total >= 50 then 'ATENCAO'
    else 'NECESSITA_REFORCO' end;
$$;

-- Desempenho por assunto. Sem argumento, devolve tudo o que quem chamou tem
-- direito de ver: para o aluno, o próprio; para o painel, a turma inteira.
create or replace function public.desempenho_por_assunto(p_aluno uuid default null)
returns table (
  assunto text, fonte_id text, fase integer,
  respostas bigint, acertos bigint, erros bigint,
  percentual_acerto numeric, tempo_medio_ms numeric,
  alunos bigint, dominio public.nivel_dominio)
language sql security invoker set search_path = public stable as $$
  select r.gerador_id as assunto,
         min(r.fonte_id) as fonte_id,
         min(r.fase) as fase,
         count(*) as respostas,
         count(*) filter (where r.correta) as acertos,
         count(*) filter (where not r.correta) as erros,
         round(count(*) filter (where r.correta)::numeric * 100 / nullif(count(*), 0), 1),
         round(avg(r.tempo_ms)::numeric, 0),
         count(distinct r.aluno_id) as alunos,
         public.classificar_dominio(count(*) filter (where r.correta), count(*))
    from public.respostas r
   where r.gerador_id <> ''
     and (p_aluno is null or r.aluno_id = p_aluno)
   group by r.gerador_id;
$$;

-- O mesmo recorte, por fonte — é o que separa "vai bem em teoria mas mal no
-- instrumento" de "vai mal em tudo".
create or replace function public.desempenho_por_fonte(p_aluno uuid default null)
returns table (fonte_id text, respostas bigint, acertos bigint,
               percentual_acerto numeric, dominio public.nivel_dominio)
language sql security invoker set search_path = public stable as $$
  select coalesce(r.fonte_id, 'SEM_FONTE'),
         count(*), count(*) filter (where r.correta),
         round(count(*) filter (where r.correta)::numeric * 100 / nullif(count(*), 0), 1),
         public.classificar_dominio(count(*) filter (where r.correta), count(*))
    from public.respostas r
   where (p_aluno is null or r.aluno_id = p_aluno)
   group by coalesce(r.fonte_id, 'SEM_FONTE');
$$;

create or replace function public.desempenho_por_habilidade(p_aluno uuid default null)
returns table (habilidade public.habilidade, respostas bigint, acertos bigint,
               percentual_acerto numeric, dominio public.nivel_dominio)
language sql security invoker set search_path = public stable as $$
  select r.habilidade, count(*), count(*) filter (where r.correta),
         round(count(*) filter (where r.correta)::numeric * 100 / nullif(count(*), 0), 1),
         public.classificar_dominio(count(*) filter (where r.correta), count(*))
    from public.respostas r
   where r.habilidade is not null and (p_aluno is null or r.aluno_id = p_aluno)
   group by r.habilidade;
$$;

create or replace function public.desempenho_por_fase(p_aluno uuid default null)
returns table (fase integer, provas bigint, respostas bigint, acertos bigint,
               percentual_acerto numeric, alunos bigint, dominio public.nivel_dominio)
language sql security invoker set search_path = public stable as $$
  select r.fase,
         count(distinct r.avaliacao_id), count(*), count(*) filter (where r.correta),
         round(count(*) filter (where r.correta)::numeric * 100 / nullif(count(*), 0), 1),
         count(distinct r.aluno_id),
         public.classificar_dominio(count(*) filter (where r.correta), count(*))
    from public.respostas r
   where r.fase is not null and (p_aluno is null or r.aluno_id = p_aluno)
   group by r.fase;
$$;

-- Dificuldade recorrente é diferente de dificuldade pontual: aqui entra só o
-- assunto que o aluno errou em provas diferentes. Errar três vezes na mesma
-- prova pode ser um dia ruim; errar em três provas é assunto a trabalhar.
create or replace function public.dificuldades_recorrentes(p_aluno uuid default null, p_minimo integer default 2)
returns table (aluno_id uuid, assunto text, fonte_id text, fase integer,
               erros bigint, provas_com_erro bigint, percentual_erro numeric,
               ultimo_erro timestamptz)
language sql security invoker set search_path = public stable as $$
  select r.aluno_id, r.gerador_id, min(r.fonte_id), min(r.fase),
         count(*) filter (where not r.correta),
         count(distinct r.avaliacao_id) filter (where not r.correta),
         round(count(*) filter (where not r.correta)::numeric * 100 / nullif(count(*), 0), 1),
         max(r.data) filter (where not r.correta)
    from public.respostas r
   where r.gerador_id <> '' and (p_aluno is null or r.aluno_id = p_aluno)
   group by r.aluno_id, r.gerador_id
  having count(distinct r.avaliacao_id) filter (where not r.correta) >= p_minimo;
$$;

-- Evolução: a nota de cada prova na ordem do tempo, com a média móvel das
-- três últimas, para separar oscilação de tendência.
create or replace function public.evolucao(p_aluno uuid default null)
returns table (aluno_id uuid, avaliacao_id text, fase integer, data timestamptz,
               nota smallint, media_3 numeric)
language sql security invoker set search_path = public stable as $$
  select a.aluno_id, a.id, f.numero, a.finalizada_em, a.nota,
         round(avg(a.nota) over (partition by a.aluno_id order by a.finalizada_em
                                 rows between 2 preceding and current row), 1)
    from public.avaliacoes a
    left join public.fases f on f.id = a.fase_id
   where a.status = 'FINALIZADA' and (p_aluno is null or a.aluno_id = p_aluno);
$$;

-- "Está pronto para avançar?" — a resposta com os porquês, não só sim ou não.
--
-- A fase entra por número, e o número vem de `fases.numero`. O `fases.id` é
-- texto ('f1'), então converter o id em inteiro quebra — foi o que aconteceu
-- na primeira versão desta função.
create or replace function public.pronto_para_avancar(p_aluno uuid, p_fase integer)
returns jsonb language sql security invoker set search_path = public stable as $$
  with base as (
    select count(*) filter (where r.correta) as acertos, count(*) as total
      from public.respostas r where r.aluno_id = p_aluno and r.fase = p_fase
  ), fracos as (
    select count(*) as n from public.desempenho_por_assunto(p_aluno) d
     where d.fase = p_fase and d.dominio in ('ATENCAO','NECESSITA_REFORCO')
  ), aprov as (
    select count(*) as n from public.avaliacoes a
     join public.fases f on f.id = a.fase_id
     where a.aluno_id = p_aluno and a.aprovado and a.status = 'FINALIZADA'
       and f.numero = p_fase
  )
  select jsonb_build_object(
    'fase', p_fase,
    'respostas', base.total,
    'percentual_acerto', round(base.acertos::numeric * 100 / nullif(base.total, 0), 1),
    'dominio', public.classificar_dominio(base.acertos, base.total),
    'assuntos_em_atencao', fracos.n,
    'avaliacoes_aprovadas', aprov.n,
    'pronto', (aprov.n > 0 and fracos.n = 0),
    'motivo', case
      when aprov.n = 0 then 'Ainda não foi aprovado na avaliação desta fase.'
      when fracos.n > 0 then format('Há %s assunto(s) em atenção ou reforço nesta fase.', fracos.n)
      else 'Avaliação aprovada e nenhum assunto em atenção.' end)
  from base, fracos, aprov;
$$;
