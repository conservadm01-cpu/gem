-- =====================================================================
-- MSAapp Violino · 0005 · políticas de acesso (RLS)
-- =====================================================================
-- "Não confiar somente no frontend para segurança." Aqui é onde isso deixa
-- de ser intenção: toda tabela nasce trancada e só abre pelo que está
-- escrito abaixo, verificado pelo servidor a cada consulta.
--
-- Toda política é `to authenticated`: visitante sem conta não lê nada.
-- O que cada papel pode vem de `tem_permissao`, que consulta o RBAC — então
-- mudar uma permissão no catálogo muda o acesso, sem reescrever política.
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array[
    'usuarios','permissoes','perfil_permissoes','usuario_permissoes','logs',
    'conteudo_versoes','fontes','cursos','fases','modulos','licoes','atividades',
    'questoes','matriz','hinos','hinario_regras','metodo_topicos',
    'turmas','turma_instrutores','matriculas','liberacoes',
    'modelos_avaliacao','avaliacoes','respostas','questoes_usadas',
    'videos','criterios_video','video_avaliacoes','perguntas',
    'medalhas','aluno_medalhas','certificados'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ----------------------------------------------------------- usuários

drop policy if exists usuarios_leitura on public.usuarios;
create policy usuarios_leitura on public.usuarios for select to authenticated
  using (id = auth.uid() or public.tem_permissao('usuario.ler'));

drop policy if exists usuarios_insercao on public.usuarios;
create policy usuarios_insercao on public.usuarios for insert to authenticated
  with check (id = auth.uid() or public.tem_permissao('usuario.escrever'));

-- A coluna `perfil` tem trava própria no gatilho: editar o próprio cadastro
-- não pode virar editar o próprio papel.
drop policy if exists usuarios_edicao on public.usuarios;
create policy usuarios_edicao on public.usuarios for update to authenticated
  using (id = auth.uid() or public.tem_permissao('usuario.escrever'))
  with check (id = auth.uid() or public.tem_permissao('usuario.escrever'));

drop policy if exists usuarios_exclusao on public.usuarios;
create policy usuarios_exclusao on public.usuarios for delete to authenticated
  using (public.eh_administrador());

-- -------------------------------------------------------------- RBAC

drop policy if exists permissoes_leitura on public.permissoes;
create policy permissoes_leitura on public.permissoes for select to authenticated using (true);

drop policy if exists perfil_permissoes_leitura on public.perfil_permissoes;
create policy perfil_permissoes_leitura on public.perfil_permissoes for select to authenticated using (true);

drop policy if exists perfil_permissoes_escrita on public.perfil_permissoes;
create policy perfil_permissoes_escrita on public.perfil_permissoes for all to authenticated
  using (public.eh_administrador()) with check (public.eh_administrador());

drop policy if exists usuario_permissoes_leitura on public.usuario_permissoes;
create policy usuario_permissoes_leitura on public.usuario_permissoes for select to authenticated
  using (usuario_id = auth.uid() or public.tem_permissao('usuario.ler'));

drop policy if exists usuario_permissoes_escrita on public.usuario_permissoes;
create policy usuario_permissoes_escrita on public.usuario_permissoes for all to authenticated
  using (public.eh_administrador()) with check (public.eh_administrador());

-- --------------------------------------------------------- auditoria

drop policy if exists logs_registro on public.logs;
create policy logs_registro on public.logs for insert to authenticated
  with check (usuario_id = auth.uid() or usuario_id is null);

drop policy if exists logs_leitura on public.logs;
create policy logs_leitura on public.logs for select to authenticated
  using (public.tem_permissao('log.ler'));

-- ---------------------------------------------------------- conteúdo

-- Conteúdo publicado é de todos; rascunho e teste são de quem revisa. É isso
-- que faz a "versão teste" existir: o encarregado abre a mesma tela do
-- aluno, com o conteúdo que o aluno ainda não vê.
do $$
declare t text;
begin
  foreach t in array array['cursos','fases','modulos','licoes','atividades'] loop
    execute format($f$
      drop policy if exists %1$I_leitura on public.%1$I;
      create policy %1$I_leitura on public.%1$I for select to authenticated
        using (status = 'PUBLICADO' or public.tem_permissao('conteudo.ler_rascunho'));
      drop policy if exists %1$I_escrita on public.%1$I;
      create policy %1$I_escrita on public.%1$I for all to authenticated
        using (public.tem_permissao('conteudo.escrever'))
        with check (public.tem_permissao('conteudo.escrever'));
    $f$, t);
  end loop;
end $$;

drop policy if exists questoes_leitura on public.questoes;
create policy questoes_leitura on public.questoes for select to authenticated
  using (status = 'PUBLICADO' or public.tem_permissao('conteudo.ler_rascunho'));

drop policy if exists questoes_escrita on public.questoes;
create policy questoes_escrita on public.questoes for all to authenticated
  using (public.tem_permissao('conteudo.escrever'))
  with check (public.tem_permissao('conteudo.escrever'));

drop policy if exists fontes_leitura on public.fontes;
create policy fontes_leitura on public.fontes for select to authenticated using (true);
drop policy if exists fontes_escrita on public.fontes;
create policy fontes_escrita on public.fontes for all to authenticated
  using (public.tem_permissao('conteudo.escrever')) with check (public.tem_permissao('conteudo.escrever'));

drop policy if exists matriz_leitura on public.matriz;
create policy matriz_leitura on public.matriz for select to authenticated
  using (public.tem_painel());
drop policy if exists matriz_escrita on public.matriz;
create policy matriz_escrita on public.matriz for all to authenticated
  using (public.tem_permissao('conteudo.escrever')) with check (public.tem_permissao('conteudo.escrever'));

drop policy if exists hinos_leitura on public.hinos;
create policy hinos_leitura on public.hinos for select to authenticated
  using (status = 'PUBLICADO' or public.tem_permissao('conteudo.ler_rascunho'));
drop policy if exists hinos_escrita on public.hinos;
create policy hinos_escrita on public.hinos for all to authenticated
  using (public.tem_permissao('conteudo.escrever')) with check (public.tem_permissao('conteudo.escrever'));

drop policy if exists hinario_regras_leitura on public.hinario_regras;
create policy hinario_regras_leitura on public.hinario_regras for select to authenticated using (true);
drop policy if exists hinario_regras_escrita on public.hinario_regras;
create policy hinario_regras_escrita on public.hinario_regras for all to authenticated
  using (public.tem_permissao('conteudo.escrever')) with check (public.tem_permissao('conteudo.escrever'));

drop policy if exists metodo_topicos_leitura on public.metodo_topicos;
create policy metodo_topicos_leitura on public.metodo_topicos for select to authenticated
  using (status = 'PUBLICADO' or public.tem_permissao('conteudo.ler_rascunho'));
drop policy if exists metodo_topicos_escrita on public.metodo_topicos;
create policy metodo_topicos_escrita on public.metodo_topicos for all to authenticated
  using (public.tem_permissao('conteudo.escrever')) with check (public.tem_permissao('conteudo.escrever'));

-- Histórico de versões: quem revisa lê, ninguém reescreve.
drop policy if exists conteudo_versoes_leitura on public.conteudo_versoes;
create policy conteudo_versoes_leitura on public.conteudo_versoes for select to authenticated
  using (public.tem_permissao('conteudo.ler_rascunho'));

-- ------------------------------------------------------------- turmas

drop policy if exists turmas_leitura on public.turmas;
create policy turmas_leitura on public.turmas for select to authenticated
  using (public.tem_painel() or exists (
    select 1 from public.matriculas m
     where m.turma_id = turmas.id and m.aluno_id = auth.uid() and m.status = 'ATIVO'));

drop policy if exists turmas_escrita on public.turmas;
create policy turmas_escrita on public.turmas for all to authenticated
  using (public.tem_permissao('turma.escrever')) with check (public.tem_permissao('turma.escrever'));

drop policy if exists turma_instrutores_leitura on public.turma_instrutores;
create policy turma_instrutores_leitura on public.turma_instrutores for select to authenticated
  using (public.tem_painel() or instrutor_id = auth.uid());
drop policy if exists turma_instrutores_escrita on public.turma_instrutores;
create policy turma_instrutores_escrita on public.turma_instrutores for all to authenticated
  using (public.tem_permissao('turma.escrever')) with check (public.tem_permissao('turma.escrever'));

drop policy if exists matriculas_leitura on public.matriculas;
create policy matriculas_leitura on public.matriculas for select to authenticated
  using (public.acompanha_aluno(aluno_id));
drop policy if exists matriculas_escrita on public.matriculas;
create policy matriculas_escrita on public.matriculas for all to authenticated
  using (public.tem_permissao('turma.escrever')) with check (public.tem_permissao('turma.escrever'));

drop policy if exists liberacoes_leitura on public.liberacoes;
create policy liberacoes_leitura on public.liberacoes for select to authenticated
  using (aluno_id is null or public.acompanha_aluno(aluno_id));
drop policy if exists liberacoes_escrita on public.liberacoes;
create policy liberacoes_escrita on public.liberacoes for all to authenticated
  using (public.tem_permissao('turma.escrever')) with check (public.tem_permissao('turma.escrever'));

-- ---------------------------------------------------------- avaliação

drop policy if exists modelos_leitura on public.modelos_avaliacao;
create policy modelos_leitura on public.modelos_avaliacao for select to authenticated using (true);
drop policy if exists modelos_escrita on public.modelos_avaliacao;
create policy modelos_escrita on public.modelos_avaliacao for all to authenticated
  using (public.tem_permissao('avaliacao.montar')) with check (public.tem_permissao('avaliacao.montar'));

drop policy if exists avaliacoes_leitura on public.avaliacoes;
create policy avaliacoes_leitura on public.avaliacoes for select to authenticated
  using (public.acompanha_aluno(aluno_id));
drop policy if exists avaliacoes_propria on public.avaliacoes;
create policy avaliacoes_propria on public.avaliacoes for all to authenticated
  using (aluno_id = auth.uid()) with check (aluno_id = auth.uid());

drop policy if exists respostas_leitura on public.respostas;
create policy respostas_leitura on public.respostas for select to authenticated
  using (public.acompanha_aluno(aluno_id));
-- Responder é do aluno, e só para frente: sem update e sem delete, para
-- ninguém reescrever a própria prova depois de ver o resultado.
drop policy if exists respostas_registro on public.respostas;
create policy respostas_registro on public.respostas for insert to authenticated
  with check (aluno_id = auth.uid());

drop policy if exists usadas_leitura on public.questoes_usadas;
create policy usadas_leitura on public.questoes_usadas for select to authenticated
  using (public.acompanha_aluno(aluno_id));
drop policy if exists usadas_escrita on public.questoes_usadas;
create policy usadas_escrita on public.questoes_usadas for all to authenticated
  using (aluno_id = auth.uid()) with check (aluno_id = auth.uid());

-- ------------------------------------------------- vídeos e perguntas

drop policy if exists videos_leitura on public.videos;
create policy videos_leitura on public.videos for select to authenticated
  using (public.acompanha_aluno(aluno_id));
drop policy if exists videos_envio on public.videos;
create policy videos_envio on public.videos for insert to authenticated
  with check (aluno_id = auth.uid() and public.tem_permissao('video.enviar'));
drop policy if exists videos_situacao on public.videos;
create policy videos_situacao on public.videos for update to authenticated
  using (public.tem_permissao('video.avaliar') and public.acompanha_aluno(aluno_id))
  with check (public.tem_permissao('video.avaliar'));
drop policy if exists videos_remocao on public.videos;
create policy videos_remocao on public.videos for delete to authenticated
  using (aluno_id = auth.uid() or public.tem_gestao());

drop policy if exists criterios_leitura on public.criterios_video;
create policy criterios_leitura on public.criterios_video for select to authenticated using (true);
drop policy if exists criterios_escrita on public.criterios_video;
create policy criterios_escrita on public.criterios_video for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists video_avaliacoes_leitura on public.video_avaliacoes;
create policy video_avaliacoes_leitura on public.video_avaliacoes for select to authenticated
  using (exists (select 1 from public.videos v where v.id = video_id and public.acompanha_aluno(v.aluno_id)));
drop policy if exists video_avaliacoes_escrita on public.video_avaliacoes;
create policy video_avaliacoes_escrita on public.video_avaliacoes for all to authenticated
  using (instrutor_id = auth.uid() and public.tem_permissao('video.avaliar'))
  with check (instrutor_id = auth.uid() and public.tem_permissao('video.avaliar'));

drop policy if exists perguntas_leitura on public.perguntas;
create policy perguntas_leitura on public.perguntas for select to authenticated
  using (public.acompanha_aluno(aluno_id));
drop policy if exists perguntas_envio on public.perguntas;
create policy perguntas_envio on public.perguntas for insert to authenticated
  with check (aluno_id = auth.uid() and public.tem_permissao('pergunta.enviar'));
drop policy if exists perguntas_resposta on public.perguntas;
create policy perguntas_resposta on public.perguntas for update to authenticated
  using (public.tem_permissao('pergunta.responder') and public.acompanha_aluno(aluno_id))
  with check (public.tem_permissao('pergunta.responder'));

-- ----------------------------------------- medalhas e certificados

drop policy if exists medalhas_leitura on public.medalhas;
create policy medalhas_leitura on public.medalhas for select to authenticated using (true);
drop policy if exists medalhas_escrita on public.medalhas;
create policy medalhas_escrita on public.medalhas for all to authenticated
  using (public.tem_gestao()) with check (public.tem_gestao());

drop policy if exists aluno_medalhas_leitura on public.aluno_medalhas;
create policy aluno_medalhas_leitura on public.aluno_medalhas for select to authenticated
  using (public.acompanha_aluno(aluno_id));
drop policy if exists aluno_medalhas_escrita on public.aluno_medalhas;
create policy aluno_medalhas_escrita on public.aluno_medalhas for insert to authenticated
  with check (aluno_id = auth.uid() or public.tem_gestao());

drop policy if exists certificados_leitura on public.certificados;
create policy certificados_leitura on public.certificados for select to authenticated
  using (public.acompanha_aluno(aluno_id));
drop policy if exists certificados_escrita on public.certificados;
create policy certificados_escrita on public.certificados for insert to authenticated
  with check (aluno_id = auth.uid() or public.tem_gestao());
