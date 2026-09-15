// Assinatura de questão e não repetição.
//
// A assinatura é o que impede a mesma pergunta de cair duas vezes para o mesmo
// aluno. Entra nela conteúdo, variante, enunciado, alternativas e dificuldade —
// tudo que define a pergunta. Fora dela fica a ORDEM das alternativas, de
// propósito: embaralhar não cria pergunta nova.

const normalizar = (t) => String(t ?? '')
  .toLowerCase()
  .normalize('NFD').replace(/[̀-ͯ]/g, '')
  .replace(/[^a-z0-9 ]/g, ' ')
  .replace(/\s+/g, ' ')
  .trim();

/** Hash estável de 32 bits, em base 36. Não é criptografia: é identidade. */
export function hash(texto) {
  let h = 2166136261;
  const s = String(texto);
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0).toString(36);
}

export function assinar({ conteudo = '', variante = '', enunciado = '', alternativas = [], dificuldade = 1 }) {
  const alts = [...alternativas].map(normalizar).sort().join('|');
  return hash([normalizar(conteudo), normalizar(variante), normalizar(enunciado), alts, dificuldade].join('#'));
}

/**
 * Duas questões são semanticamente próximas quando o enunciado normalizado
 * compartilha a maior parte das palavras. Serve para não colocar lado a lado
 * duas formas da mesma pergunta na mesma prova.
 */
export function proximas(a, b, limite = 0.8) {
  const pa = new Set(normalizar(a).split(' ').filter((p) => p.length > 3));
  const pb = new Set(normalizar(b).split(' ').filter((p) => p.length > 3));
  if (!pa.size || !pb.size) return false;
  let comuns = 0;
  pa.forEach((p) => { if (pb.has(p)) comuns++; });
  return comuns / Math.min(pa.size, pb.size) >= limite;
}

/**
 * Sorteia sem repetir. Devolve também `esgotou`, para a tela poder avisar que
 * o banco precisa de questões novas em vez de reciclar em silêncio.
 */
export function sortearIneditas(universo, usadas, quantidade, aleatorio = Math.random) {
  const jaVistas = new Set(usadas);
  const ineditas = universo.filter((q) => !jaVistas.has(q.assinatura));
  const escolhidas = [];
  const disponiveis = [...ineditas];

  while (escolhidas.length < quantidade && disponiveis.length) {
    const i = Math.floor(aleatorio() * disponiveis.length);
    const candidata = disponiveis.splice(i, 1)[0];
    const parecida = escolhidas.some((e) => proximas(e.enunciado, candidata.enunciado));
    if (!parecida) escolhidas.push(candidata);
  }
  return {
    questoes: escolhidas,
    esgotou: escolhidas.length < quantidade,
    ineditasRestantes: Math.max(0, ineditas.length - escolhidas.length),
  };
}
