// Ponto de entrada. Monta a moldura, registra as rotas e liga os eventos.

import { html, texto, cru } from './nucleo/html.js';
import { ler, definir, aoMudar, avisar, limparAviso } from './nucleo/estado.js';
import { registrar, iniciar, resolver, ir, caminhoAtual } from './nucleo/roteador.js';
import { MENUS } from './dominio/permissoes.js';
import { dados, modo } from './dados/index.js';
import { telaEntrar, ligarEntrar } from './telas/entrar.js';
import * as aluno from './telas/aluno.js';
import * as avaliacao from './telas/avaliacao.js';
import * as painel from './telas/painel.js';

const raiz = document.getElementById('app');
const TODOS = ['ADMINISTRADOR', 'ENCARREGADO', 'INSTRUTOR', 'ALUNO'];
const PAINEL = ['ADMINISTRADOR', 'ENCARREGADO', 'INSTRUTOR'];
const GESTAO = ['ADMINISTRADOR', 'ENCARREGADO'];

// ------------------------------------------------------------------ rotas

registrar('/entrar', { tela: telaEntrar });
registrar('/', { perfis: TODOS, tela: async () => (ler().sessao.perfil === 'ALUNO' ? aluno.inicio() : painel.dashboard()) });
registrar('/msa', { perfis: TODOS, tela: aluno.msa });
registrar('/violino', { perfis: TODOS, tela: aluno.violino });
registrar('/metodos', { perfis: PAINEL, tela: aluno.violino });
registrar('/hinario', { perfis: TODOS, tela: aluno.hinario });
registrar('/progresso', { perfis: ['ALUNO'], tela: aluno.progresso });
registrar('/medalhas', { perfis: ['ALUNO'], tela: aluno.medalhas });
registrar('/avaliacoes', { perfis: TODOS, tela: async () => (ler().sessao.perfil === 'ALUNO' ? avaliacao.telaAvaliacoes() : painel.aprovacoes()) });
registrar('/prova', { perfis: ['ALUNO'], tela: async () => avaliacao.telaProva() });
registrar('/usuarios', { perfis: GESTAO, tela: painel.usuarios });
registrar('/alunos', { perfis: PAINEL, tela: painel.dashboard });
registrar('/turmas', { perfis: PAINEL, tela: painel.turmas });
registrar('/fontes', { perfis: GESTAO, tela: painel.fontesTela });
registrar('/aprovacoes', { perfis: GESTAO, tela: painel.aprovacoes });
registrar('/logs', { perfis: GESTAO, tela: painel.logs });
registrar('/backup', { perfis: GESTAO, tela: painel.backup });
registrar('/dificuldades', { perfis: PAINEL, tela: painel.dashboard });
registrar('/evolucao', { perfis: PAINEL, tela: painel.dashboard });

// Rotas previstas nos menus que ainda não têm tela própria. Declaradas de
// propósito: é melhor dizer "em desenvolvimento" do que dar 404 em item de menu.
['curso', 'exercicios', 'jogos', 'videos', 'perguntas', 'certificados',
 'conteudos', 'relatorios', 'questoes', 'analytics', 'permissoes', 'configuracoes']
  .forEach((r) => registrar(`/${r}`, { perfis: TODOS, tela: async () => emDesenvolvimento(r) }));

const emDesenvolvimento = (nome) => html`
  <h1>${nome}</h1>
  <p class="aviso pendente"><b>[EM DESENVOLVIMENTO]</b> Esta tela ainda não foi construída.
  A estrutura de dados e as permissões dela já existem; falta a interface.</p>`;

// ---------------------------------------------------------------- moldura

function moldura(conteudo) {
  const s = ler().sessao;
  if (!s) return texto(conteudo);
  const menu = MENUS[s.perfil] || [];
  const atual = `#${caminhoAtual()}`;
  return texto(html`
    <div class="moldura">
      <header class="barra-topo">
        <span class="marca-app">MSAapp Violino</span>
        <span class="quem"><b>${s.nome}</b>${s.perfil.toLowerCase()}</span>
        <button class="botao secundario" data-acao="sair" style="min-height:38px;padding:8px 14px">Sair</button>
      </header>
      <div class="corpo">
        <nav class="menu">${menu.map(([href, rotulo]) => html`
          <a href="${href}" class="${cru(atual === href ? 'ativo' : '')}">${rotulo}</a>`)}</nav>
        <main class="pagina">${conteudo}</main>
      </div>
    </div>`);
}

async function desenhar({ tela, params, erro }) {
  const aviso = ler().aviso;
  let conteudo;
  try {
    if (erro === 'sem-sessao') { ir('/entrar'); return; }
    if (erro === 'sem-permissao') conteudo = html`<h1>Sem permissão</h1><p class="aviso erro">Seu perfil não alcança esta tela.</p>`;
    else if (erro) conteudo = html`<h1>Não encontrada</h1><p class="mini">Esta rota não existe.</p>`;
    else conteudo = await tela(params);
  } catch (e) {
    console.error(e);
    conteudo = html`<h1>Erro</h1><p class="aviso erro">${e.message}</p>`;
  }
  const cabeca = aviso ? html`<p class="aviso ${cru(aviso.tipo === 'erro' ? 'erro' : '')}">${aviso.texto}</p>` : '';
  raiz.innerHTML = moldura(html`${cabeca}${conteudo}`);
  if (aviso) limparAviso();
  if (!ler().sessao) ligarEntrar(raiz);
  raiz.scrollTop = 0;
  window.scrollTo(0, 0);
}

// ----------------------------------------------------------------- eventos

document.addEventListener('click', async (evento) => {
  const irPara = evento.target.closest('[data-ir]');
  if (irPara) { ir(irPara.dataset.ir.replace(/^#/, '')); return; }

  const botao = evento.target.closest('[data-acao]');
  if (!botao) return;
  const acao = botao.dataset.acao;

  if (acao === 'sair') { await dados.sair(); definir({ sessao: null }); ir('/entrar'); return; }

  if (acao === 'prova:iniciar') {
    botao.disabled = true;
    if (await avaliacao.iniciar(botao.dataset.fonte)) ir('/prova');
    else { botao.disabled = false; resolver(); }
    return;
  }
  if (acao === 'prova:responder') { await avaliacao.responder(botao.dataset.valor); resolver(); return; }
  if (acao === 'prova:proxima') { await avaliacao.proxima(); resolver(); return; }

  if (acao === 'backup:json' || acao === 'backup:csv') {
    try {
      const formato = acao.endsWith('csv') ? 'csv' : 'json';
      const conteudo = await dados.exportar(formato);
      const blob = new Blob([conteudo], { type: formato === 'json' ? 'application/json' : 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = `msaapp-violino.${formato}`;
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 2000);
      avisar(`Backup ${formato.toUpperCase()} gerado.`);
    } catch (e) { avisar(e.message, 'erro'); }
    resolver();
  }
});

// Busca do hinário: filtra sem recarregar a página.
document.addEventListener('input', (evento) => {
  if (evento.target.id !== 'busca-hino') return;
  clearTimeout(window.__buscaHino);
  const valor = evento.target.value;
  window.__buscaHino = setTimeout(async () => {
    raiz.querySelector('main.pagina').innerHTML = texto(await aluno.hinario({ busca: valor }));
    const campo = raiz.querySelector('#busca-hino');
    if (campo) { campo.value = valor; campo.focus(); campo.setSelectionRange(valor.length, valor.length); }
  }, 250);
});

// Aviso de ação (erro de login, backup gerado) só aparece se algo redesenhar.
// Redesenha ao surgir o aviso, não ao limpá-lo — senão os dois se chamariam
// em círculo.
aoMudar((estado) => { if (estado.aviso) resolver(); });

// -------------------------------------------------------------------- carga

(async function comecar() {
  try {
    const sessao = await dados.sessao();
    definir({ sessao });
  } catch (erro) {
    console.error(erro);
  }
  iniciar(desenhar);
  if (!ler().sessao && caminhoAtual() !== '/entrar') ir('/entrar');
})();

// Exposto só para os testes de navegador conseguirem inspecionar o estado.
window.__msaapp = { ler, dados, modo };
