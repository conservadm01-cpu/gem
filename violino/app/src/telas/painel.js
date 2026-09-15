// Telas de instrutor, encarregado e administrador. O que muda entre os três é
// o alcance dos dados — e quem decide o alcance é a camada de dados, não a
// tela: aqui nada filtra por perfil "na mão".

import { html, cru } from '../nucleo/html.js';
import { dados, modo } from '../dados/index.js';
import { ler, avisar } from '../nucleo/estado.js';
import { selo, numero, cartao, barras, tabela, vazio, pendente, aviso } from '../ui/componentes.js';

const eu = () => ler().sessao;

/** MODO PROFESSOR: o aluno visto pedagogicamente, como pede a seção 38. */
async function fichaDoAluno(aluno) {
  const [fontes, dific, pronto, videos] = await Promise.all([
    dados.desempenhoPorFonte(aluno.aluno), dados.dificuldadesRecorrentes(aluno.aluno),
    dados.prontoParaAvancar(aluno.aluno), dados.videos(aluno.aluno),
  ]);
  const porFonte = Object.fromEntries(fontes.map((f) => [f.chave, f.percentual_acerto]));
  const principal = dific[0];
  const ultimo = videos[videos.length - 1];
  return html`<section class="cartao">
    <h3>${aluno.nome} ${selo(pronto.dominio)}</h3>
    <div class="numeros">
      ${numero(`${pronto.percentual_acerto}%`, 'geral')}
      ${numero(`${porFonte.MSA ?? '—'}${porFonte.MSA !== undefined ? '%' : ''}`, 'MSA')}
      ${numero(`${porFonte.METODO_VIOLINO ?? '—'}${porFonte.METODO_VIOLINO !== undefined ? '%' : ''}`, 'violino')}
      ${numero(`${porFonte.HINARIO ?? '—'}${porFonte.HINARIO !== undefined ? '%' : ''}`, 'hinário')}
    </div>
    <p class="mini"><b>Principal dificuldade:</b> ${principal ? principal.chave : 'nenhuma medida ainda'}</p>
    <p class="mini"><b>Erro recorrente:</b> ${principal ? `${principal.erros} erros em ${principal.provasComErro} avaliações` : '—'}</p>
    <p class="mini"><b>Recomendação:</b> ${principal ? 'revisar o conteúdo correspondente na fonte' : 'seguir o plano'}</p>
    <p class="mini"><b>Último vídeo:</b> ${ultimo ? `${ultimo.titulo} — ${ultimo.status.toLowerCase()}` : 'nenhum enviado'}</p>
    <p class="mini"><b>Situação:</b> ${pronto.pronto ? 'pode avançar' : pronto.motivo}</p>
  </section>`;
}

export async function dashboard() {
  const [turmas, alunos, dific, fontes] = await Promise.all([
    dados.turmas(), dados.matriculas(), dados.dificuldadesRecorrentes(), dados.desempenhoPorFonte(),
  ]);
  const fichas = await Promise.all(alunos.slice(0, 6).map(fichaDoAluno));
  return html`
    <h1>Dashboard</h1>
    ${modo === 'memoria' ? aviso('Modo demonstração: os dados vivem neste aparelho. Com o banco configurado, o mesmo app passa a falar com o servidor.', 'pendente') : ''}
    <div class="numeros">
      ${numero(turmas.length, 'turmas')}
      ${numero(alunos.length, 'alunos')}
      ${numero(dific.length, 'dificuldades recorrentes')}
    </div>
    ${cartao('Desempenho por fonte', fontes.length
      ? barras(fontes.map((f) => ({ nome: f.chave, valor: f.percentual_acerto, detalhe: `${f.acertos} de ${f.total} · ${f.alunos} aluno(s)` })))
      : vazio('Nenhuma avaliação feita ainda.'))}
    ${dific.length ? cartao('Conteúdos com maior dificuldade', tabela([
      { titulo: 'Assunto', celula: (x) => x.chave },
      { titulo: 'Erro', num: true, celula: (x) => `${x.percentual_erro}%` },
      { titulo: 'Alunos', num: true, celula: (x) => x.alunos },
      { titulo: 'Tipo', celula: (x) => x.tipo_de_erro.replace(/_/g, ' ').toLowerCase() },
    ], dific)) : ''}
    <h2>Alunos</h2>
    ${fichas.length ? fichas : vazio('Nenhum aluno sob seu acompanhamento.')}`;
}

export async function usuarios() {
  const lista = await dados.usuarios();
  return html`
    <h1>Usuários</h1>
    ${tabela([
      { titulo: 'Nome', celula: (u) => u.nome },
      { titulo: 'E-mail', celula: (u) => u.email },
      { titulo: 'Perfil', celula: (u) => u.perfil },
      { titulo: 'Situação', celula: (u) => u.status },
    ], lista)}
    <p class="mini">Mudar papel de conta é ato de administrador — e o banco recusa quem não for,
    independentemente do que a tela ofereça.</p>`;
}

export async function turmas() {
  const [lista, matriculas] = await Promise.all([dados.turmas(), dados.matriculas()]);
  return html`
    <h1>Turmas</h1>
    ${tabela([
      { titulo: 'Turma', celula: (t) => t.nome },
      { titulo: 'Código', celula: (t) => t.codigo },
      { titulo: 'Nível', celula: (t) => t.nivel },
      { titulo: 'Alunos', num: true, celula: (t) => matriculas.filter((m) => m.turma === t.id && m.status === 'ATIVO').length },
      { titulo: 'Situação', celula: (t) => t.status },
    ], lista)}`;
}

export async function fontesTela() {
  const [lista, topicos, hinos, regras] = await Promise.all([
    dados.fontes(), dados.topicosDoMetodo(), dados.hinos(), dados.regrasDoHinario(),
  ]);
  const comMeta = hinos.filter((h) => h.compasso && !String(h.compasso).startsWith('VALIDA')).length;
  return html`
    <h1>Fontes</h1>
    ${lista.map((f) => html`<section class="cartao">
      <h3>${f.nome}</h3>
      <p class="mini">${f.id}</p>
      ${f.situacao === 'PENDENTE DE FONTE' ? pendente('PENDENTE DE FONTE') : selo('EM_DESENVOLVIMENTO')}
    </section>`)}
    ${cartao('O que já está no sistema', html`
      <div class="rolagem"><table><tbody>
        <tr><td>Hinos e coros indexados</td><td class="num">${hinos.length}</td></tr>
        <tr><td>Hinos com metadados lidos da partitura</td><td class="num">${comMeta}</td></tr>
        <tr><td>Regras do hinário transcritas</td><td class="num">${regras.length}</td></tr>
        <tr><td>Módulos do método de violino</td><td class="num">${topicos.length} (sem conteúdo)</td></tr>
      </tbody></table></div>`)}
    ${aviso('Importação de novas fontes (PDF, DOCX, TXT, JSON, CSV, imagem, áudio, vídeo): [EM DESENVOLVIMENTO]. O fluxo previsto é arquivo → extração → classificação → matriz → validação → rascunho → teste → aprovação → publicação, sem publicação automática.', 'pendente')}`;
}

export async function logs() {
  try {
    const lista = await dados.logs(80);
    return html`
      <h1>Logs</h1>
      <p class="mini">A trilha só cresce: não há edição nem exclusão, nem para administrador.</p>
      ${tabela([
        { titulo: 'Quando', celula: (l) => new Date(l.data_hora).toLocaleString('pt-BR') },
        { titulo: 'Ação', celula: (l) => l.acao },
        { titulo: 'Entidade', celula: (l) => `${l.entidade} ${l.entidade_id}`.trim() },
        { titulo: 'Resultado', celula: (l) => l.resultado },
      ], lista)}`;
  } catch (erro) {
    return html`<h1>Logs</h1>${aviso(erro.message, 'erro')}`;
  }
}

export async function backup() {
  return html`
    <h1>Backup</h1>
    <p class="mini">Exporta usuários, turmas, avaliações, respostas, vídeos, perguntas, medalhas,
    certificados e logs.</p>
    <div class="acoes">
      <button class="botao" data-acao="backup:json">Exportar JSON</button>
      <button class="botao secundario" data-acao="backup:csv">Exportar CSV</button>
    </div>`;
}

export async function aprovacoes() {
  const questoes = await dados.questoes();
  return html`
    <h1>Aprovações</h1>
    <p class="mini">Fluxo: rascunho → teste → aprovado → publicado. Nada vai para o aluno sem passar
    pela versão teste, que mostra a questão exatamente como ele verá.</p>
    ${cartao(`Banco gerado das fontes (${questoes.length} questões)`, html`
      ${questoes.slice(0, 5).map((q) => html`<div style="margin-bottom:14px">
        <b>${q.enunciado}</b>
        <p class="mini">Resposta: ${q.resposta} · ${q.tipo} · dificuldade ${q.dificuldade} · ${q.habilidade}</p>
        <p class="mini">Fonte: ${q.referencia}</p>
      </div>`)}
      <p class="mini">Mostrando 5 de ${questoes.length}.</p>`)}`;
}
