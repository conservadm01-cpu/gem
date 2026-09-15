// Peças de tela reaproveitadas. Tudo devolve `html` marcado, nunca texto solto.

import { html, cru, escapar } from '../nucleo/html.js';
import { NIVEIS } from '../dominio/dominio.js';

export const selo = (dominio) => {
  const classe = { DOMINIO: 'dominio', EM_DESENVOLVIMENTO: 'desenvolvimento',
    ATENCAO: 'atencao', REFORCO: 'reforco', SEM_DADOS: 'sem' }[dominio] || 'sem';
  return html`<span class="selo ${cru(classe)}">${(NIVEIS[dominio] || {}).rotulo || dominio}</span>`;
};

export const pendente = (texto) => html`<span class="selo pendente">${texto}</span>`;

export const numero = (valor, rotulo) => html`
  <div class="numero"><strong>${valor}</strong><span>${rotulo}</span></div>`;

export const cartao = (titulo, conteudo) => html`
  <section class="cartao">${titulo ? html`<h3>${titulo}</h3>` : ''}${conteudo}</section>`;

export const aviso = (texto, tipo = '') => html`<p class="aviso ${cru(tipo)}">${texto}</p>`;

/**
 * Barras horizontais, escala sempre 0 a 100. Encolher o eixo para as barras
 * preencherem a tela faria 12% de erro parecer catástrofe.
 */
export const barras = (itens) => html`
  <ol class="barras">
    ${itens.map((i) => html`<li>
      <div class="nome">${i.nome}${i.detalhe ? html`<br><span class="mini">${i.detalhe}</span>` : ''}</div>
      <div class="valor">${i.valor}%</div>
      <div class="trilho" title="${i.titulo || ''}">
        <span class="barra" style="width:${cru(String(i.valor === 0 ? 0 : Math.max(1.5, i.valor)))}%"></span>
      </div>
    </li>`)}
  </ol>`;

export const tabela = (colunas, linhas) => html`
  <div class="rolagem"><table>
    <thead><tr>${colunas.map((c) => html`<th class="${cru(c.num ? 'num' : '')}">${c.titulo}</th>`)}</tr></thead>
    <tbody>${linhas.map((l) => html`<tr>${colunas.map((c) => html`<td class="${cru(c.num ? 'num' : '')}">${c.celula(l)}</td>`)}</tr>`)}</tbody>
  </table></div>`;

export const vazio = (texto) => html`<p class="mini">${texto}</p>`;
