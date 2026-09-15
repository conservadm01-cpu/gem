// Telas do aluno. A pergunta que cada uma responde está no comentário —
// são as sete da seção 37 do código mestre.

import { html, cru } from '../nucleo/html.js';
import { dados } from '../dados/index.js';
import { ler, avisar } from '../nucleo/estado.js';
import { ir } from '../nucleo/roteador.js';
import { selo, numero, cartao, barras, tabela, vazio, pendente, aviso } from '../ui/componentes.js';

const eu = () => ler().sessao;

/** ONDE ESTOU? QUAL É MEU PRÓXIMO PASSO? */
export async function inicio() {
  const [pronto, fontes, recs, medalhas] = await Promise.all([
    dados.prontoParaAvancar(), dados.desempenhoPorFonte(), dados.recomendacoes(), dados.medalhasDoAluno(),
  ]);
  return html`
    <h1>Olá, ${eu().nome}</h1>
    <div class="numeros">
      ${numero(`${pronto.percentual_acerto}%`, 'aproveitamento')}
      ${numero(pronto.respostas, 'questões')}
      ${numero(pronto.avaliacoes_aprovadas, 'aprovações')}
      ${numero(medalhas.length, 'medalhas')}
    </div>
    ${cartao('Estou pronto para avançar?', html`
      <p><b>${pronto.pronto ? 'Sim.' : 'Ainda não.'}</b> ${pronto.motivo}</p>
      ${selo(pronto.dominio)}`)}
    ${cartao('Por fonte', fontes.length
      ? barras(fontes.map((f) => ({ nome: f.chave, valor: f.percentual_acerto, detalhe: `${f.acertos} de ${f.total}` })))
      : vazio('Faça uma avaliação para este quadro aparecer.'))}
    ${recs.length ? cartao('O que revisar', html`
      ${recs.map((r) => html`<div style="margin-bottom:12px">
        <b>${r.assunto}</b> ${selo('ATENCAO')}
        <p class="mini">${r.porque}</p>
        ${r.revisar.texto ? html`<p class="mini">Fonte: “${r.revisar.texto}”</p>` : pendente('VALIDAÇÃO NECESSÁRIA')}
      </div>`)}`) : ''}
    <div class="acoes">
      <button class="botao" data-ir="#/avaliacoes">Fazer uma avaliação</button>
      <button class="botao secundario" data-ir="#/hinario">Abrir o hinário</button>
    </div>`;
}

/** O QUE ESTOU ESTUDANDO? — MSA */
export async function msa() {
  const fases = await dados.fases();
  return html`
    <h1>MSA</h1>
    <p class="mini">Método Simplificado de Aprendizagem Musical — Congregação Cristã no Brasil,
    1ª edição (dez/2022). Cada lição indica a página do livro.</p>
    ${tabela([
      { titulo: 'Fase', celula: (f) => `${f.numero}` },
      { titulo: 'Assunto', celula: (f) => f.titulo },
      { titulo: 'Lições', num: true, celula: (f) => f.licoes },
      { titulo: 'Assuntos avaliados', num: true, celula: (f) => f.assuntos },
    ], fases)}`;
}

/** O QUE ESTOU ESTUDANDO? — Violino */
export async function violino() {
  const topicos = await dados.topicosDoMetodo();
  return html`
    <h1>Violino</h1>
    ${aviso('O método de violino ainda não foi incorporado: o PDF original não está disponível. A estrutura dos dez módulos já existe e recebe o conteúdo assim que a fonte chegar.', 'pendente')}
    ${topicos.map((t) => html`<section class="cartao">
      <h3>${String(t.ordem).padStart(2, '0')} · ${t.titulo}</h3>
      <p class="mini">${t.indicadores}</p>
      ${pendente('PENDENTE DE FONTE')}
    </section>`)}`;
}

/** Hinário: índice real, com busca. */
export async function hinario(params) {
  const busca = (params && params.busca) || '';
  const [lista, regras] = await Promise.all([dados.hinos(busca), dados.regrasDoHinario()]);
  const mostrar = lista.slice(0, 60);
  return html`
    <h1>Hinário</h1>
    ${cartao('Regras para o violino', html`
      ${regras.filter((r) => r.violino).map((r) => html`
        <p><b>${r.assunto}.</b> ${r.texto}</p>`)}
      <p class="mini">Hinário CCB nº 5 — instruções de utilização para instrumentos de cordas.</p>`)}
    <section class="cartao">
      <label for="busca-hino">Buscar por número ou nome</label>
      <input id="busca-hino" type="search" value="${busca}" placeholder="ex.: 41 ou 'Rocha'">
    </section>
    <p class="mini">${lista.length} resultado(s)${lista.length > 60 ? ' — mostrando os 60 primeiros' : ''}.</p>
    ${tabela([
      { titulo: '#', num: true, celula: (h) => h.numero },
      { titulo: 'Nome', celula: (h) => h.nome },
      { titulo: 'Compasso', celula: (h) => h.compasso && !String(h.compasso).startsWith('VALIDA') ? h.compasso : cru('<span class="selo pendente">pendente</span>') },
      { titulo: 'Armadura', celula: (h) => h.armadura && !String(h.armadura).startsWith('VALIDA') ? h.armadura : cru('<span class="selo pendente">pendente</span>') },
      { titulo: 'Metrônomo', celula: (h) => h.andamento_min ? `${h.andamento_min}–${h.andamento_max}` : cru('<span class="selo pendente">pendente</span>') },
    ], mostrar)}`;
}

/** COMO ESTOU INDO? ONDE ESTOU ERRANDO? */
export async function progresso() {
  const [assunto, habilidade, dificuldades, evol] = await Promise.all([
    dados.desempenhoPorAssunto(), dados.desempenhoPorHabilidade(),
    dados.dificuldadesRecorrentes(), dados.evolucao(),
  ]);
  return html`
    <h1>Meu progresso</h1>
    ${cartao('Erro por assunto', assunto.length
      ? barras(assunto.map((a) => ({ nome: a.chave, valor: a.percentual_erro, detalhe: `${a.erros} de ${a.total}` })))
      : vazio('Ainda sem respostas.'))}
    ${cartao('Por habilidade', habilidade.length
      ? tabela([
        { titulo: 'Habilidade', celula: (h) => h.chave },
        { titulo: 'Acerto', num: true, celula: (h) => `${h.percentual_acerto}%` },
        { titulo: 'Situação', celula: (h) => selo(h.dominio) },
      ], habilidade) : vazio('Ainda sem respostas.'))}
    ${dificuldades.length ? cartao('Erros que se repetem', tabela([
      { titulo: 'Assunto', celula: (x) => x.chave },
      { titulo: 'Erros', num: true, celula: (x) => x.erros },
      { titulo: 'Em quantas provas', num: true, celula: (x) => x.provasComErro },
      { titulo: 'Tipo', celula: (x) => x.tipo_de_erro.replace(/_/g, ' ').toLowerCase() },
    ], dificuldades)) : ''}
    ${evol.length > 1 ? cartao('Evolução', barras(evol.map((e, i) => ({
      nome: `Avaliação ${i + 1}`, valor: e.nota, detalhe: `média das 3 últimas: ${e.media_3}%` })))) : ''}`;
}

export async function medalhas() {
  const [catalogo, minhas] = await Promise.all([dados.medalhas(), dados.medalhasDoAluno()]);
  const tenho = new Set(minhas.map((m) => m.medalha));
  return html`
    <h1>Medalhas</h1>
    <div class="grade">
      ${catalogo.map((m) => html`<section class="cartao" style="${cru(tenho.has(m.id) ? '' : 'opacity:.55')}">
        <h3>${m.nome}</h3><p class="mini">${m.descricao}</p>
        ${tenho.has(m.id) ? selo('DOMINIO') : html`<span class="selo sem">ainda não</span>`}
      </section>`)}
    </div>`;
}
