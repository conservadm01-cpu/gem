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
