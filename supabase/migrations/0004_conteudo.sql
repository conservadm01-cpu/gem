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
  if not public.tem_gestao() then
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
