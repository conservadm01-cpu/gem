// Segunda metade da camada em memória: avaliação, analytics, acompanhamento e
// gamificação. Separada por tamanho, não por assunto — o contrato é um só.

import { carregar, exigir, acompanha, log, guardar, _interno } from './mock.js';
import { classificar, percentual, classificarErro } from '../dominio/dominio.js';
import { montarProva } from '../dominio/gerador.js';

const agora = () => new Date().toISOString();
const id = (pre) => `${pre}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
const d = () => _interno.dados;
const eu = () => _interno.sessao;

// ---------------------------------------------------------------- avaliação

export async function montarAvaliacao({ quantidade = 10, fonte = null } = {}) {
  await carregar();
  if (!eu()) throw new Error('Entre na sua conta.');
  const usadas = d().respostas.filter((r) => r.aluno === eu().id).map((r) => r.assinatura);
  const universo = fonte ? d().universo.filter((q) => q.fonte === fonte) : d().universo;
  const { questoes, esgotou, ineditasRestantes } = montarProva({ universo, usadas, quantidade });

  if (!questoes.length) {
    throw new Error('O banco de questões desta fonte já foi todo utilizado. É preciso cadastrar questões novas.');
  }
  const avaliacao = {
    id: id('av'), aluno: eu().id, iniciada_em: agora(), status: 'EM_ANDAMENTO',
    questoes: questoes.map((q) => q.id), total: questoes.length, acertos: 0, esgotou, ineditasRestantes,
  };
  d().avaliacoes.push(avaliacao);
  log('AVALIACAO_INICIADA', 'avaliacao', avaliacao.id, 'OK', { questoes: questoes.length, esgotou });
  return { avaliacao, questoes };
}

export async function registrarResposta({ avaliacaoId, questao, resposta, tempoMs }) {
  await carregar();
  if (!eu()) throw new Error('Entre na sua conta.');
  const correta = resposta === questao.resposta;
  d().respostas.push({
    id: id('r'), avaliacao: avaliacaoId, aluno: eu().id, questao: questao.id,
    assinatura: questao.assinatura, molde: questao.molde, fonte: questao.fonte,
    dificuldade: questao.dificuldade, habilidade: questao.habilidade,
    resposta, correta, tempo_ms: tempoMs || null, data: agora(),
  });
  log('QUESTAO_RESPONDIDA', 'questao', questao.id, correta ? 'ACERTO' : 'ERRO');
  guardar();
  return { correta, explicacao: questao.explicacao, referencia: questao.referencia };
}

export async function finalizarAvaliacao(avaliacaoId) {
  await carregar();
  const av = d().avaliacoes.find((a) => a.id === avaliacaoId);
  if (!av) throw new Error('Avaliação não encontrada.');
  const minhas = d().respostas.filter((r) => r.avaliacao === avaliacaoId);
  av.acertos = minhas.filter((r) => r.correta).length;
  av.total = minhas.length || av.total;
  av.nota = percentual(av.acertos, av.total);
  av.aprovado = av.nota >= 70;
  av.status = 'FINALIZADA';
  av.finalizada_em = agora();
  log('AVALIACAO_FINALIZADA', 'avaliacao', av.id, 'OK', { nota: av.nota });
  await conferirMedalhas();
  guardar();
  return av;
}

export async function avaliacoesDoAluno(alunoId = null) {
  await carregar();
  const alvo = alunoId || (eu() && eu().id);
  if (!acompanha(alvo)) return [];
  return d().avaliacoes.filter((a) => a.aluno === alvo).sort((a, b) => String(b.iniciada_em).localeCompare(String(a.iniciada_em)));
}

// ---------------------------------------------------------------- analytics

const visiveis = () => d().respostas.filter((r) => acompanha(r.aluno));

function agrupar(linhas, chave) {
  const mapa = new Map();
  for (const r of linhas) {
    const k = chave(r);
    if (k === undefined || k === null || k === '') continue;
    if (!mapa.has(k)) mapa.set(k, { chave: k, total: 0, acertos: 0, erros: 0, tempo: 0, comTempo: 0, alunos: new Set(), provasComErro: new Set() });
    const g = mapa.get(k);
    g.total++; g.alunos.add(r.aluno);
    if (r.correta) g.acertos++; else { g.erros++; g.provasComErro.add(r.avaliacao); }
    if (r.tempo_ms) { g.tempo += r.tempo_ms; g.comTempo++; }
  }
  return [...mapa.values()].map((g) => ({
    chave: g.chave, total: g.total, acertos: g.acertos, erros: g.erros,
    percentual_acerto: percentual(g.acertos, g.total),
    percentual_erro: percentual(g.erros, g.total),
    tempo_medio_ms: g.comTempo ? Math.round(g.tempo / g.comTempo) : null,
    alunos: g.alunos.size, provasComErro: g.provasComErro.size,
    dominio: classificar(g.acertos, g.total),
  }));
}

export async function desempenhoPorAssunto(alunoId = null) {
  await carregar();
  const linhas = alunoId ? visiveis().filter((r) => r.aluno === alunoId) : visiveis();
  return agrupar(linhas, (r) => r.molde).sort((a, b) => b.percentual_erro - a.percentual_erro);
}
export async function desempenhoPorFonte(alunoId = null) {
  await carregar();
  const linhas = alunoId ? visiveis().filter((r) => r.aluno === alunoId) : visiveis();
  return agrupar(linhas, (r) => r.fonte).sort((a, b) => a.percentual_acerto - b.percentual_acerto);
}
export async function desempenhoPorHabilidade(alunoId = null) {
  await carregar();
  const linhas = alunoId ? visiveis().filter((r) => r.aluno === alunoId) : visiveis();
  return agrupar(linhas, (r) => r.habilidade).sort((a, b) => a.percentual_acerto - b.percentual_acerto);
}

export async function dificuldadesRecorrentes(alunoId = null) {
  const lista = await desempenhoPorAssunto(alunoId);
  return lista
    .map((g) => ({ ...g, tipo_de_erro: classificarErro({ erros: g.erros, provasComErro: g.provasComErro, total: g.total }) }))
    .filter((g) => ['ERRO_RECORRENTE', 'DIFICULDADE_PERSISTENTE'].includes(g.tipo_de_erro));
}

export async function evolucao(alunoId = null) {
  const avs = await avaliacoesDoAluno(alunoId);
  return avs.filter((a) => a.status === 'FINALIZADA').reverse().map((a, i, todas) => {
    const janela = todas.slice(Math.max(0, i - 2), i + 1);
    return { avaliacao: a.id, data: a.finalizada_em, nota: a.nota,
      media_3: Math.round(janela.reduce((s, x) => s + x.nota, 0) / janela.length) };
  });
}

export async function prontoParaAvancar(alunoId = null) {
  await carregar();
  const alvo = alunoId || (eu() && eu().id);
  const linhas = visiveis().filter((r) => r.aluno === alvo);
  const acertos = linhas.filter((r) => r.correta).length;
  const fracos = (await desempenhoPorAssunto(alvo)).filter((g) => ['ATENCAO', 'REFORCO'].includes(g.dominio));
  const aprovadas = (await avaliacoesDoAluno(alvo)).filter((a) => a.aprovado).length;
  return {
    respostas: linhas.length,
    percentual_acerto: percentual(acertos, linhas.length),
    dominio: classificar(acertos, linhas.length),
    assuntos_em_atencao: fracos.length,
    avaliacoes_aprovadas: aprovadas,
    pronto: aprovadas > 0 && fracos.length === 0,
    motivo: aprovadas === 0 ? 'Ainda não foi aprovado em nenhuma avaliação.'
      : fracos.length ? `Há ${fracos.length} assunto(s) em atenção ou reforço.`
      : 'Avaliação aprovada e nenhum assunto em atenção.',
  };
}

/**
 * Recomendação. Só nasce de dificuldade medida, e sempre aponta para conteúdo
 * da fonte — nunca para explicação inventada pelo sistema.
 */
export async function recomendacoes(alunoId = null) {
  const dificuldades = await dificuldadesRecorrentes(alunoId);
  const regras = d().regras;
  return dificuldades.slice(0, 5).map((g) => {
    const regra = regras.find((r) => g.chave.startsWith('hin.'));
    return {
      assunto: g.chave,
      porque: `Você errou ${g.erros} de ${g.total} questões deste assunto, em ${g.provasComErro} avaliações diferentes.`,
      tipo_de_erro: g.tipo_de_erro,
      revisar: g.chave.startsWith('hin.')
        ? { tipo: 'REGRA_DO_HINARIO', referencia: regra ? regra.id : '', texto: regra ? regra.texto : '' }
        : { tipo: 'LICAO', referencia: 'VALIDAÇÃO NECESSÁRIA' },
    };
  });
}

// ------------------------------------------------------------ acompanhamento

export async function videos(alunoId = null) {
  await carregar();
  return d().videos.filter((v) => acompanha(v.aluno) && (!alunoId || v.aluno === alunoId));
}
export async function enviarVideo({ titulo, descricao, pergunta, contexto, contextoId, arquivo }) {
  await carregar(); exigir('video.enviar');
  const v = { id: id('v'), aluno: eu().id, titulo, descricao, pergunta, contexto, contexto_id: contextoId,
    arquivo: arquivo || '(demonstração — arquivo não enviado)', status: 'ENVIADO', enviado_em: agora(), avaliacoes: [] };
  d().videos.push(v);
  log('VIDEO_ENVIADO', 'video', v.id);
  guardar();
  return v;
}
export async function avaliarVideo(videoId, notas, status = 'APROVADO') {
  await carregar(); exigir('video.avaliar');
  const v = d().videos.find((x) => x.id === videoId);
  if (!v) throw new Error('Vídeo não encontrado.');
  if (!acompanha(v.aluno)) throw new Error('Este aluno não é de uma turma sua.');
  v.avaliacoes = Object.entries(notas).map(([criterio, n]) => ({ criterio, nota: Number(n.nota), comentario: n.comentario || '', instrutor: eu().id, data: agora() }));
  v.status = status;
  log(status === 'REGRAVAR' ? 'VIDEO_REPROVADO' : 'VIDEO_AVALIADO', 'video', videoId, 'OK', { status });
  guardar();
  return v;
}

export async function perguntas(alunoId = null) {
  await carregar();
  return d().perguntas.filter((p) => acompanha(p.aluno) && (!alunoId || p.aluno === alunoId));
}
export async function perguntar({ conteudo, contexto, contextoId, tipo = 'TEXTO' }) {
  await carregar(); exigir('pergunta.enviar');
  const p = { id: id('p'), aluno: eu().id, tipo, conteudo, contexto, contexto_id: contextoId, enviada_em: agora(), resposta: '' };
  d().perguntas.push(p);
  log('DUVIDA_CRIADA', 'pergunta', p.id);
  guardar();
  return p;
}
export async function responderPergunta(perguntaId, resposta) {
  await carregar(); exigir('pergunta.responder');
  const p = d().perguntas.find((x) => x.id === perguntaId);
  if (!p) throw new Error('Pergunta não encontrada.');
  if (!acompanha(p.aluno)) throw new Error('Este aluno não é de uma turma sua.');
  p.resposta = resposta; p.instrutor = eu().id; p.respondida_em = agora();
  log('RESPOSTA_INSTRUTOR', 'pergunta', perguntaId);
  guardar();
  return p;
}

// --------------------------------------------------------------- gamificação

const CATALOGO = [
  { id: 'bronze', nome: 'Bronze', criterio: { tipo: 'avaliacoes_aprovadas', valor: 1 }, descricao: 'Primeira avaliação aprovada' },
  { id: 'prata', nome: 'Prata', criterio: { tipo: 'avaliacoes_aprovadas', valor: 5 }, descricao: 'Cinco avaliações aprovadas' },
  { id: 'ouro', nome: 'Ouro', criterio: { tipo: 'avaliacoes_aprovadas', valor: 10 }, descricao: 'Dez avaliações aprovadas' },
  { id: 'mestre_hinario', nome: 'Mestre do Hinário', criterio: { tipo: 'dominio_na_fonte', fonte: 'HINARIO' }, descricao: '85% ou mais no Hinário' },
  { id: 'mestre_msa', nome: 'Mestre MSA', criterio: { tipo: 'dominio_na_fonte', fonte: 'MSA' }, descricao: '85% ou mais no MSA' },
  { id: 'mestre_violino', nome: 'Mestre do Violino', criterio: { tipo: 'dominio_na_fonte', fonte: 'METODO_VIOLINO' }, descricao: '85% ou mais no método' },
  { id: 'musico_formacao', nome: 'Músico em Formação', criterio: { tipo: 'videos_aprovados', valor: 1 }, descricao: 'Vídeo aprovado pelo instrutor' },
];

export async function medalhas() { await carregar(); return CATALOGO; }
export async function medalhasDoAluno(alunoId = null) {
  await carregar();
  const alvo = alunoId || (eu() && eu().id);
  if (!acompanha(alvo)) return [];
  return d().medalhasDoAluno.filter((m) => m.aluno === alvo);
}

/** Critérios objetivos: nada de medalha por esforço percebido. */
async function conferirMedalhas() {
  const alvo = eu() && eu().id;
  if (!alvo) return;
  const avs = d().avaliacoes.filter((a) => a.aluno === alvo && a.aprovado).length;
  const porFonte = await desempenhoPorFonte(alvo);
  const videosOk = d().videos.filter((v) => v.aluno === alvo && v.status === 'APROVADO').length;
  for (const m of CATALOGO) {
    if (d().medalhasDoAluno.some((x) => x.aluno === alvo && x.medalha === m.id)) continue;
    let ganhou = false;
    if (m.criterio.tipo === 'avaliacoes_aprovadas') ganhou = avs >= m.criterio.valor;
    if (m.criterio.tipo === 'videos_aprovados') ganhou = videosOk >= m.criterio.valor;
    if (m.criterio.tipo === 'dominio_na_fonte') {
      const f = porFonte.find((x) => x.chave === m.criterio.fonte);
      ganhou = Boolean(f && f.dominio === 'DOMINIO');
    }
    if (ganhou) {
      d().medalhasDoAluno.push({ aluno: alvo, medalha: m.id, conquistada_em: agora() });
      log('MEDALHA_CONQUISTADA', 'medalha', m.id);
    }
  }
}

export async function certificados(alunoId = null) {
  await carregar();
  const alvo = alunoId || (eu() && eu().id);
  if (!acompanha(alvo)) return [];
  return d().certificados.filter((c) => c.aluno === alvo);
}

// -------------------------------------------------------------------- sistema

export async function logs(limite = 100) {
  await carregar(); exigir('log.ler');
  return d().logs.slice(-limite).reverse();
}
export async function registrarLog(acao, entidade, entidadeId, resultado, metadata) {
  await carregar(); log(acao, entidade, entidadeId, resultado, metadata); return true;
}

export async function exportar(formato = 'json') {
  await carregar(); exigir('backup.exportar');
  const pacote = {
    gerado_em: agora(),
    usuarios: d().usuarios.map(({ senha, ...u }) => u),
    turmas: d().turmas, matriculas: d().matriculas,
    avaliacoes: d().avaliacoes, respostas: d().respostas,
    videos: d().videos, perguntas: d().perguntas,
    medalhas: d().medalhasDoAluno, certificados: d().certificados, logs: d().logs,
  };
  log('BACKUP_REALIZADO', 'sistema', '', 'OK', { formato });
  if (formato === 'json') return JSON.stringify(pacote, null, 2);
  const linhas = [['tabela', 'id', 'dados'].join(',')];
  for (const [tabela, lista] of Object.entries(pacote)) {
    if (!Array.isArray(lista)) continue;
    lista.forEach((x, i) => linhas.push([tabela, x.id || i, `"${JSON.stringify(x).replace(/"/g, '""')}"`].join(',')));
  }
  return linhas.join('\n');
}
