// O contrato da camada de dados.
//
// Existe para que trocar memória por servidor não toque em tela nenhuma. As
// telas falam só com estes nomes; quem implementa é `mock.js` ou
// `supabase.js`, escolhido em `index.js` conforme o config.
//
// Toda implementação deve devolver Promise e lançar Error com mensagem em
// português quando falhar — as telas mostram a mensagem como veio.

export const CONTRATO = [
  // acesso
  'entrar', 'sair', 'sessao', 'usuarios', 'salvarUsuario', 'definirPapel',
  // conteúdo
  'fontes', 'fases', 'modulos', 'licoes', 'questoes',
  'salvarConteudo', 'mudarStatus', 'versoes',
  // hinário e método
  'hinos', 'hino', 'regrasDoHinario', 'topicosDoMetodo',
  // matriz
  'matriz',
  // turmas
  'turmas', 'salvarTurma', 'matriculas', 'matricular', 'transferir',
  // avaliação
  'montarAvaliacao', 'registrarResposta', 'finalizarAvaliacao', 'avaliacoesDoAluno',
  // desempenho
  'desempenhoPorAssunto', 'desempenhoPorFonte', 'desempenhoPorHabilidade',
  'dificuldadesRecorrentes', 'evolucao', 'prontoParaAvancar', 'recomendacoes',
  // acompanhamento
  'videos', 'enviarVideo', 'avaliarVideo', 'perguntas', 'perguntar', 'responderPergunta',
  // gamificação
  'medalhas', 'medalhasDoAluno', 'certificados',
  // sistema
  'logs', 'registrarLog', 'exportar',
];

/** Confere na carga se a implementação cumpre o contrato inteiro. */
export function conferirContrato(impl, nome) {
  const faltando = CONTRATO.filter((m) => typeof impl[m] !== 'function');
  if (faltando.length) {
    throw new Error(`A camada de dados "${nome}" não implementa: ${faltando.join(', ')}`);
  }
  return impl;
}
