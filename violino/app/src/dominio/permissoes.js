// Espelho do RBAC do banco, para a interface não oferecer o que o servidor vai
// recusar. É conveniência, não segurança: quem decide é o Postgres, a cada
// consulta. Se este arquivo e o banco discordarem, o banco ganha.

export const PERFIS = ['ADMINISTRADOR', 'ENCARREGADO', 'INSTRUTOR', 'ALUNO'];

export const PERMISSOES_POR_PERFIL = {
  ADMINISTRADOR: ['*'],
  ENCARREGADO: [
    'usuario.ler', 'usuario.escrever', 'turma.ler', 'turma.escrever',
    'conteudo.ler', 'conteudo.ler_rascunho', 'conteudo.escrever',
    'conteudo.aprovar', 'conteudo.publicar', 'questao.gerar',
    'avaliacao.montar', 'desempenho.turma', 'desempenho.geral',
    'video.avaliar', 'pergunta.responder', 'log.ler', 'backup.exportar',
  ],
  INSTRUTOR: [
    'usuario.ler', 'turma.ler', 'conteudo.ler', 'conteudo.ler_rascunho',
    'avaliacao.montar', 'desempenho.turma', 'video.avaliar', 'pergunta.responder',
  ],
  ALUNO: [
    'conteudo.ler', 'avaliacao.responder', 'desempenho.proprio',
    'video.enviar', 'pergunta.enviar',
  ],
};

export function pode(sessao, permissao) {
  if (!sessao) return false;
  const lista = PERMISSOES_POR_PERFIL[sessao.perfil] || [];
  return lista.includes('*') || lista.includes(permissao);
}

// Os menus dos quatro perfis, conforme as seções 33 a 36 do código mestre.
export const MENUS = {
  ALUNO: [
    ['#/', 'Início'], ['#/curso', 'Meu curso'], ['#/msa', 'MSA'],
    ['#/violino', 'Violino'], ['#/hinario', 'Hinário'], ['#/exercicios', 'Exercícios'],
    ['#/jogos', 'Jogos'], ['#/avaliacoes', 'Avaliações'], ['#/videos', 'Vídeos'],
    ['#/perguntas', 'Perguntas'], ['#/medalhas', 'Medalhas'],
    ['#/certificados', 'Certificados'], ['#/progresso', 'Meu progresso'],
  ],
  INSTRUTOR: [
    ['#/', 'Dashboard'], ['#/turmas', 'Turmas'], ['#/alunos', 'Alunos'],
    ['#/conteudos', 'Conteúdos'], ['#/avaliacoes', 'Avaliações'], ['#/videos', 'Vídeos'],
    ['#/perguntas', 'Perguntas'], ['#/dificuldades', 'Dificuldades'],
    ['#/evolucao', 'Evolução'], ['#/relatorios', 'Relatórios'],
  ],
  ENCARREGADO: [
    ['#/', 'Dashboard'], ['#/usuarios', 'Usuários'], ['#/turmas', 'Turmas'],
    ['#/conteudos', 'Conteúdos'], ['#/metodos', 'Métodos'], ['#/msa', 'MSA'],
    ['#/hinario', 'Hinário'], ['#/avaliacoes', 'Avaliações'],
    ['#/aprovacoes', 'Aprovações'], ['#/relatorios', 'Relatórios'],
  ],
  ADMINISTRADOR: [
    ['#/', 'Dashboard'], ['#/usuarios', 'Usuários'], ['#/permissoes', 'Permissões'],
    ['#/turmas', 'Turmas'], ['#/conteudos', 'Conteúdos'], ['#/fontes', 'Fontes'],
    ['#/metodos', 'Métodos'], ['#/msa', 'MSA'], ['#/hinario', 'Hinário'],
    ['#/questoes', 'Questões'], ['#/avaliacoes', 'Avaliações'],
    ['#/analytics', 'Analytics'], ['#/logs', 'Logs'], ['#/backup', 'Backup'],
    ['#/configuracoes', 'Configurações'],
  ],
};
