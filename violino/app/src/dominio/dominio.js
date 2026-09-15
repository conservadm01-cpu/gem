// Classificação de domínio, na escala do projeto.
//
// Abaixo do mínimo de respostas não classifica: errar a única questão de um
// assunto daria 0% e mandaria para reforço sem razão nenhuma.

export const MINIMO_DE_RESPOSTAS = 4;

export const NIVEIS = {
  DOMINIO: { rotulo: 'Domínio', ordem: 4 },
  EM_DESENVOLVIMENTO: { rotulo: 'Em desenvolvimento', ordem: 3 },
  ATENCAO: { rotulo: 'Atenção', ordem: 2 },
  REFORCO: { rotulo: 'Necessita reforço', ordem: 1 },
  SEM_DADOS: { rotulo: 'Ainda sem dados', ordem: 0 },
};

export function classificar(acertos, total, minimo = MINIMO_DE_RESPOSTAS) {
  if (!total || total < minimo) return 'SEM_DADOS';
  const pct = (acertos / total) * 100;
  if (pct >= 85) return 'DOMINIO';
  if (pct >= 70) return 'EM_DESENVOLVIMENTO';
  if (pct >= 50) return 'ATENCAO';
  return 'REFORCO';
}

export const percentual = (parte, todo) => (todo > 0 ? Math.round((parte / todo) * 100) : 0);

/**
 * Erro isolado, recorrente ou dificuldade persistente.
 *
 * O que separa um do outro não é a quantidade de erros, é em quantas provas
 * diferentes eles aconteceram: errar três vezes na mesma prova pode ser um dia
 * ruim; errar em três provas é assunto a trabalhar.
 */
export function classificarErro({ erros = 0, provasComErro = 0, total = 0 }) {
  if (!erros) return 'SEM_ERRO';
  if (provasComErro >= 3 && percentual(erros, total) >= 50) return 'DIFICULDADE_PERSISTENTE';
  if (provasComErro >= 2) return 'ERRO_RECORRENTE';
  return 'ERRO_ISOLADO';
}

export const ROTULO_ERRO = {
  SEM_ERRO: 'sem erro',
  ERRO_ISOLADO: 'erro isolado',
  ERRO_RECORRENTE: 'erro recorrente',
  DIFICULDADE_PERSISTENTE: 'dificuldade persistente',
};
