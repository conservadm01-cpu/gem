// A avaliação. O ciclo do princípio de ouro acontece aqui: o aluno responde,
// o sistema registra, e a resposta já sai do fluxo com fonte e explicação.

import { html, cru } from '../nucleo/html.js';
import { dados } from '../dados/index.js';
import { avisar } from '../nucleo/estado.js';
import { cartao, aviso, selo, numero } from '../ui/componentes.js';

let prova = null;      // { avaliacao, questoes }
let indice = 0;
let inicioDaQuestao = 0;
let respondida = null;

export async function telaAvaliacoes() {
  const anteriores = await dados.avaliacoesDoAluno();
  return html`
    <h1>Avaliações</h1>
    ${cartao('Nova avaliação', html`
      <p class="mini">As questões são sorteadas do que já foi extraído das fontes, sem repetir
      o que você já respondeu. Cada uma traz a referência de onde veio.</p>
      <div class="acoes">
        <button class="botao" data-acao="prova:iniciar" data-fonte="">Começar (todas as fontes)</button>
        <button class="botao secundario" data-acao="prova:iniciar" data-fonte="HINARIO">Só Hinário</button>
      </div>`)}
    ${anteriores.length ? cartao('Anteriores', html`
      <div class="rolagem"><table>
        <thead><tr><th>Data</th><th class="num">Nota</th><th>Resultado</th></tr></thead>
        <tbody>${anteriores.filter((a) => a.status === 'FINALIZADA').map((a) => html`<tr>
          <td>${new Date(a.finalizada_em).toLocaleString('pt-BR')}</td>
          <td class="num">${a.nota}%</td>
          <td>${a.aprovado ? selo('DOMINIO') : selo('ATENCAO')}</td>
        </tr>`)}</tbody>
      </table></div>`) : ''}`;
}

export async function iniciar(fonte) {
  try {
    prova = await dados.montarAvaliacao({ quantidade: 10, fonte: fonte || null });
    indice = 0; respondida = null; inicioDaQuestao = Date.now();
    return true;
  } catch (erro) {
    avisar(erro.message, 'erro');
    return false;
  }
}

export function telaProva() {
  if (!prova) return html`<p class="aviso">Nenhuma avaliação em andamento.</p>`;
  if (indice >= prova.questoes.length) return telaResultado();

  const q = prova.questoes[indice];
  return html`
    <p class="mini">Questão ${indice + 1} de ${prova.questoes.length}</p>
    ${prova.esgotou ? aviso('O banco de questões inéditas acabou antes de completar a prova. É preciso cadastrar questões novas.', 'pendente') : ''}
    <section class="cartao">
      <h2>${q.enunciado}</h2>
      ${q.alternativas.map((a) => html`
        <button class="alternativa ${cru(classeDa(a, q))}" data-acao="prova:responder"
          data-valor="${a}" ${cru(respondida ? 'disabled' : '')}>${a}</button>`)}
      ${respondida ? html`
        <p class="${cru(respondida.correta ? 'mini' : 'aviso erro')}">
          ${respondida.correta ? 'Certo. ' : 'Não é essa. '}${respondida.explicacao}</p>
        <p class="mini">Fonte: ${q.referencia}</p>
        <div class="acoes"><button class="botao" data-acao="prova:proxima">
          ${indice + 1 >= prova.questoes.length ? 'Ver resultado' : 'Próxima'}</button></div>` : ''}
    </section>`;
}

function classeDa(alternativa, q) {
  if (!respondida) return '';
  if (alternativa === q.resposta) return 'certa';
  if (alternativa === respondida.escolha) return 'errada';
  return '';
}

export async function responder(valor) {
  if (!prova || respondida) return;
  const q = prova.questoes[indice];
  const r = await dados.registrarResposta({
    avaliacaoId: prova.avaliacao.id, questao: q, resposta: valor,
    tempoMs: Date.now() - inicioDaQuestao,
  });
  respondida = { ...r, escolha: valor };
}

export async function proxima() {
  indice++; respondida = null; inicioDaQuestao = Date.now();
  if (indice >= prova.questoes.length) {
    prova.resultado = await dados.finalizarAvaliacao(prova.avaliacao.id);
  }
}

function telaResultado() {
  const r = prova.resultado || {};
  return html`
    <h1>Resultado</h1>
    <div class="numeros">
      ${numero(`${r.nota ?? 0}%`, 'nota')}
      ${numero(r.acertos ?? 0, 'acertos')}
      ${numero((r.total ?? 0) - (r.acertos ?? 0), 'erros')}
    </div>
    ${cartao('', html`
      <p><b>${r.aprovado ? 'Aprovado.' : 'Ainda não desta vez.'}</b></p>
      <p class="mini">Cada resposta foi registrada com assunto, habilidade, dificuldade e tempo —
      é o que alimenta o seu progresso e o acompanhamento do instrutor.</p>
      <div class="acoes">
        <button class="botao" data-ir="#/progresso">Ver meu progresso</button>
        <button class="botao secundario" data-ir="#/avaliacoes">Voltar</button>
      </div>`)}`;
}

export const emAndamento = () => Boolean(prova) && indice < (prova ? prova.questoes.length : 0);
export const limpar = () => { prova = null; indice = 0; respondida = null; };
