// Roteador por hash, com guarda de perfil.
//
// A guarda aqui é conveniência de navegação, não segurança: quem decide o que
// cada pessoa pode ver é o banco, a cada consulta. Esconder um menu impede o
// engano; não impede o mal-intencionado — e é por isso que a regra vive no
// servidor também.

import { ler } from './estado.js';

const rotas = [];
let aoNavegar = () => {};

/** `caminho` aceita partes fixas e `:parametro`. */
export function registrar(caminho, { perfis = null, tela }) {
  const partes = caminho.split('/').filter(Boolean);
  rotas.push({ partes, perfis, tela, caminho });
}

function casar(atual) {
  for (const rota of rotas) {
    if (rota.partes.length !== atual.length) continue;
    const params = {};
    let bate = true;
    for (let i = 0; i < rota.partes.length; i++) {
      const p = rota.partes[i];
      if (p.startsWith(':')) params[p.slice(1)] = decodeURIComponent(atual[i]);
      else if (p !== atual[i]) { bate = false; break; }
    }
    if (bate) return { rota, params };
  }
  return null;
}

export const caminhoAtual = () => window.location.hash.replace(/^#/, '') || '/';

export function ir(destino) {
  if (caminhoAtual() === destino) resolver();
  else window.location.hash = destino;
}

export function resolver() {
  const partes = caminhoAtual().split('/').filter(Boolean);
  const achou = casar(partes);
  const sessao = ler().sessao;

  if (!achou) return aoNavegar({ erro: 'nao-encontrada', caminho: caminhoAtual() });
  if (achou.rota.perfis) {
    if (!sessao) return aoNavegar({ erro: 'sem-sessao' });
    if (!achou.rota.perfis.includes(sessao.perfil)) return aoNavegar({ erro: 'sem-permissao' });
  }
  return aoNavegar({ tela: achou.rota.tela, params: achou.params, caminho: caminhoAtual() });
}

export function iniciar(callback) {
  aoNavegar = callback;
  window.addEventListener('hashchange', resolver);
  resolver();
}
