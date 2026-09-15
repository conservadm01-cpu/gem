// Montagem de HTML a partir de texto, com escape por padrão.
//
// `html` é uma tag de template: tudo que entra por interpolação é escapado,
// a não ser que venha marcado como confiável por `cru()`. Assim o caminho
// fácil é o seguro — o contrário de escapar só quando alguém lembra.

const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
export const escapar = (t) => String(t ?? '').replace(/[&<>"']/g, (c) => ESCAPES[c]);

const CRU = Symbol('html-cru');
export const cru = (texto) => ({ [CRU]: String(texto) });
const ehCru = (v) => v && typeof v === 'object' && CRU in v;

function resolver(valor) {
  if (valor === null || valor === undefined || valor === false) return '';
  if (ehCru(valor)) return valor[CRU];
  if (Array.isArray(valor)) return valor.map(resolver).join('');
  return escapar(valor);
}

export function html(partes, ...valores) {
  // O valor de índice i fica ENTRE partes[i] e partes[i+1]. Montar na ordem
  // errada embaralha o HTML inteiro sem dar erro nenhum — o atributo de uma
  // tag vai parar no texto da seguinte.
  let saida = partes[0];
  for (let i = 0; i < valores.length; i++) saida += resolver(valores[i]) + partes[i + 1];
  return cru(saida);
}

/** Texto final para jogar no DOM. */
export const texto = (v) => (ehCru(v) ? v[CRU] : escapar(v));
