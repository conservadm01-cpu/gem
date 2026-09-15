// Camada de dados em memória.
//
// Não é maquete: aplica as mesmas regras de acesso que o banco aplica, para o
// modo demonstração não mentir sobre o que cada perfil enxerga. Quando o
// `supabase.js` entrar no lugar, as telas não mudam — é o que o contrato
// garante.
//
// Persiste no navegador só a sessão e o que o aluno produz (respostas, vídeos,
// perguntas). O conteúdo vem dos arquivos extraídos das fontes.

import { pode } from '../dominio/permissoes.js';
import { classificar, percentual, classificarErro } from '../dominio/dominio.js';
import { universoDeQuestoes, MOLDES_HINARIO, MOLDES_REGRA, montarProva } from '../dominio/gerador.js';
import { hash } from '../dominio/assinatura.js';

const CHAVE = 'msaapp.violino.v1';

const base = (caminho) => new URL(caminho, document.baseURI).href;
const agora = () => new Date().toISOString();
const id = (pre) => `${pre}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;

// Contas de demonstração: uma por perfil, para dar para experimentar os quatro
// lados sem servidor. A senha é a mesma e está à vista de propósito — isto é
// demonstração, e o aviso na tela de entrada diz isso.
const CONTAS = [
  { id: 'u-adm', nome: 'Administradora', email: 'admin@msaapp', perfil: 'ADMINISTRADOR', senha: '123' },
  { id: 'u-enc', nome: 'Encarregado', email: 'encarregado@msaapp', perfil: 'ENCARREGADO', senha: '123' },
  { id: 'u-ins', nome: 'Instrutor', email: 'instrutor@msaapp', perfil: 'INSTRUTOR', senha: '123' },
  { id: 'u-alu', nome: 'João', email: 'aluno@msaapp', perfil: 'ALUNO', senha: '123' },
  { id: 'u-alu2', nome: 'Ana', email: 'ana@msaapp', perfil: 'ALUNO', senha: '123' },
];

let dados = null;
let sessaoAtual = null;

function guardado() {
  try { return JSON.parse(localStorage.getItem(CHAVE)) || {}; } catch { return {}; }
}
function guardar() {
  try {
    localStorage.setItem(CHAVE, JSON.stringify({
      sessao: sessaoAtual, respostas: dados.respostas, avaliacoes: dados.avaliacoes,
      videos: dados.videos, perguntas: dados.perguntas, logs: dados.logs.slice(-300),
      medalhas: dados.medalhasDoAluno, certificados: dados.certificados,
    }));
  } catch { /* sem espaço: a sessão vale enquanto a aba estiver aberta */ }
}

async function carregar() {
  if (dados) return dados;
  const [hinos, regras, matriz] = await Promise.all([
    fetch(base('dados/hinos.json')).then((r) => r.json()),
    fetch(base('dados/hinario-regras.json')).then((r) => r.json()),
    fetch(base('dados/matriz.json')).then((r) => r.json()),
  ]);
  const anterior = guardado();
  dados = {
    usuarios: CONTAS.map((c) => ({ ...c, status: 'ATIVO', criado_em: agora() })),
    hinos, regras: regras.regras, matriz,
    turmas: [{ id: 't-1', nome: 'Violino — sábado', codigo: 'VIO-SAB', instrutor: 'u-ins', encarregado: 'u-enc', nivel: 'Iniciante', status: 'ATIVA' }],
    matriculas: [{ turma: 't-1', aluno: 'u-alu', status: 'ATIVO' }, { turma: 't-1', aluno: 'u-alu2', status: 'ATIVO' }],
    avaliacoes: anterior.avaliacoes || [],
    respostas: anterior.respostas || [],
    videos: anterior.videos || [],
    perguntas: anterior.perguntas || [],
    logs: anterior.logs || [],
    medalhasDoAluno: anterior.medalhas || [],
    certificados: anterior.certificados || [],
  };
  sessaoAtual = anterior.sessao || null;

  // Universo de questões do Hinário, gerado das fontes na carga.
  const doHinario = universoDeQuestoes(
    dados.hinos.filter((h) => h.compasso && !String(h.compasso).startsWith('VALIDA')),
    MOLDES_HINARIO, { fonteId: 'HINARIO' });
  const dasRegras = universoDeQuestoes(dados.regras, MOLDES_REGRA, { fonteId: 'HINARIO' });
  dados.universo = [...doHinario.questoes, ...dasRegras.questoes];
  dados.recusadas = [...doHinario.recusadas, ...dasRegras.recusadas];
  return dados;
}

function exigir(permissao) {
  if (!pode(sessaoAtual, permissao)) throw new Error('Sem permissão para esta operação.');
}
const ehMeu = (alunoId) => sessaoAtual && sessaoAtual.id === alunoId;
function acompanha(alunoId) {
  if (!sessaoAtual) return false;
  if (ehMeu(alunoId)) return true;
  if (['ADMINISTRADOR', 'ENCARREGADO'].includes(sessaoAtual.perfil)) return true;
  if (sessaoAtual.perfil === 'INSTRUTOR') {
    const minhas = dados.turmas.filter((t) => t.instrutor === sessaoAtual.id).map((t) => t.id);
    return dados.matriculas.some((m) => m.aluno === alunoId && minhas.includes(m.turma));
  }
  return false;
}

function log(acao, entidade = '', entidadeId = '', resultado = 'OK', metadata = {}) {
  dados.logs.push({ id: dados.logs.length + 1, usuario: sessaoAtual ? sessaoAtual.id : null,
    acao, data_hora: agora(), entidade, entidade_id: entidadeId, resultado, metadata });
  guardar();
}

// ------------------------------------------------------------------ acesso

async function entrar(email, senha) {
  await carregar();
  const conta = dados.usuarios.find((u) => u.email === String(email).trim().toLowerCase());
  if (!conta || conta.senha !== String(senha)) {
    log('LOGIN_FALHA', 'usuario', String(email), 'NEGADO', { email });
    throw new Error('E-mail ou senha não conferem.');
  }
  sessaoAtual = { id: conta.id, nome: conta.nome, perfil: conta.perfil, email: conta.email };
  log('LOGIN', 'usuario', conta.id);
  guardar();
  return sessaoAtual;
}
async function sair() { await carregar(); log('LOGOUT'); sessaoAtual = null; guardar(); }
async function sessao() { await carregar(); return sessaoAtual; }

async function usuarios() {
  await carregar(); exigir('usuario.ler');
  return dados.usuarios.map(({ senha, ...u }) => u);
}
async function salvarUsuario(u) {
  await carregar(); exigir('usuario.escrever');
  const i = dados.usuarios.findIndex((x) => x.id === u.id);
  if (i >= 0) { Object.assign(dados.usuarios[i], u); log('USUARIO_EDITADO', 'usuario', u.id); }
  else { dados.usuarios.push({ ...u, id: u.id || id('u'), status: 'ATIVO', criado_em: agora() }); log('USUARIO_CRIADO', 'usuario', u.id || ''); }
  return true;
}
async function definirPapel(usuarioId, perfil) {
  await carregar();
  if (!sessaoAtual || sessaoAtual.perfil !== 'ADMINISTRADOR') throw new Error('Só um administrador muda o papel de uma conta.');
  const u = dados.usuarios.find((x) => x.id === usuarioId);
  if (!u) throw new Error('Conta não encontrada.');
  u.perfil = perfil;
  log('PERMISSAO_ALTERADA', 'usuario', usuarioId, 'OK', { perfil });
  return true;
}

// ---------------------------------------------------------------- conteúdo

const FONTES = [
  { id: 'MSA', nome: 'Método Simplificado de Aprendizagem Musical', situacao: 'PARCIAL' },
  { id: 'METODO_VIOLINO', nome: 'Método de Violino (Violino Schmoll CCB)', situacao: 'PENDENTE DE FONTE' },
  { id: 'HINARIO', nome: 'Hinário CCB nº 5', situacao: 'PARCIAL' },
];
const TOPICOS = [
  ['mv.instrumento', 'Instrumento', 'Conhecimento do instrumento', 'Partes do violino; manutenção.'],
  ['mv.arco', 'Arco', 'O arco', 'Partes do arco; pegada; movimentos; sinais; exercícios de arcada.'],
  ['mv.postura', 'Postura', 'Postura e posicionamento', 'Posição do corpo; posição do violino.'],
  ['mv.afinacao', 'Afinação', 'Afinação', 'Cordas soltas; procedimentos.'],
  ['mv.mao_esquerda', 'Mão esquerda', 'Mão esquerda', 'Posicionamento; dedos; exercícios progressivos.'],
  ['mv.leitura', 'Leitura', 'Leitura aplicada ao violino', 'Leitura aplicada ao violino.'],
  ['mv.escalas', 'Escalas', 'Escalas', 'Escalas; progressão técnica.'],
  ['mv.posicoes', 'Posições', 'Posições', 'Posições; terceira posição; quinta posição.'],
  ['mv.tecnicas', 'Técnicas', 'Técnicas de arco', 'Staccato; martelato; saltellato.'],
  ['mv.harmonicos', 'Harmônicos', 'Harmônicos', 'Conteúdo específico de harmônicos.'],
];

async function fontes() { await carregar(); return FONTES; }
async function topicosDoMetodo() {
  await carregar();
  return TOPICOS.map(([tid, area, titulo, indicadores], i) => ({
    id: tid, ordem: i + 1, area, titulo, indicadores,
    status: 'RASCUNHO', conteudo: 'PENDENTE DE FONTE',
    observacao: 'VALIDAÇÃO NECESSÁRIA — aguardando o PDF original do Método Violino Schmoll CCB',
  }));
}
async function fases() {
  await carregar();
  const vistas = new Map();
  dados.matriz.filter((m) => m.fonte === 'MSA' && m.fase).forEach((m) => {
    if (!vistas.has(m.fase)) vistas.set(m.fase, { numero: m.fase, titulo: m.assunto, subtitulo: m.subassunto, licoes: 0, assuntos: 0 });
    const f = vistas.get(m.fase);
    if (m.tipo_de_atividade === 'LICAO') f.licoes++;
    if (m.tipo_de_atividade === 'QUESTAO') f.assuntos++;
  });
  return [...vistas.values()].sort((a, b) => a.numero - b.numero);
}
async function modulos() { await carregar(); return (await fases()).map((f) => ({ id: `MSA-F${String(f.numero).padStart(2, '0')}`, fonte: 'MSA', ...f })); }
async function licoes(fase) {
  await carregar();
  return dados.matriz.filter((m) => m.tipo_de_atividade === 'LICAO' && (!fase || m.fase === Number(fase)));
}
async function questoes() { await carregar(); return dados.universo; }
async function matriz() { await carregar(); return dados.matriz; }
async function salvarConteudo() { exigir('conteudo.escrever'); throw new Error('Edição de conteúdo: [EM DESENVOLVIMENTO].'); }
async function mudarStatus(entidade, entidadeId, status) {
  await carregar();
  exigir(status === 'PUBLICADO' ? 'conteudo.publicar' : status === 'APROVADO' ? 'conteudo.aprovar' : 'conteudo.escrever');
  log(status === 'PUBLICADO' ? 'CONTEUDO_PUBLICADO' : status === 'APROVADO' ? 'CONTEUDO_APROVADO' : 'CONTEUDO_EDITADO', entidade, entidadeId, 'OK', { status });
  return true;
}
async function versoes() { await carregar(); return []; }

// ------------------------------------------------------------------ hinário

async function hinos(filtro = '') {
  await carregar();
  const t = String(filtro).trim().toLowerCase();
  if (!t) return dados.hinos;
  return dados.hinos.filter((h) => String(h.numero) === t || h.nome.toLowerCase().includes(t));
}
async function hino(numero) { await carregar(); return dados.hinos.find((h) => String(h.numero) === String(numero)) || null; }
async function regrasDoHinario() { await carregar(); return dados.regras; }

// ------------------------------------------------------------------ turmas

async function turmas() {
  await carregar();
  if (!sessaoAtual) return [];
  if (sessaoAtual.perfil === 'INSTRUTOR') return dados.turmas.filter((t) => t.instrutor === sessaoAtual.id);
  if (sessaoAtual.perfil === 'ALUNO') {
    const minhas = dados.matriculas.filter((m) => m.aluno === sessaoAtual.id).map((m) => m.turma);
    return dados.turmas.filter((t) => minhas.includes(t.id));
  }
  return dados.turmas;
}
async function salvarTurma(t) {
  await carregar(); exigir('turma.escrever');
  const i = dados.turmas.findIndex((x) => x.id === t.id);
  if (i >= 0) { Object.assign(dados.turmas[i], t); log('TURMA_EDITADA', 'turma', t.id); }
  else { dados.turmas.push({ ...t, id: t.id || id('t') }); log('TURMA_CRIADA', 'turma', t.id || ''); }
  return true;
}
async function matriculas(turmaId) {
  await carregar();
  return dados.matriculas.filter((m) => (!turmaId || m.turma === turmaId) && acompanha(m.aluno))
    .map((m) => ({ ...m, nome: (dados.usuarios.find((u) => u.id === m.aluno) || {}).nome }));
}
async function matricular(turmaId, alunoId) {
  await carregar(); exigir('turma.escrever');
  if (!dados.matriculas.some((m) => m.turma === turmaId && m.aluno === alunoId)) dados.matriculas.push({ turma: turmaId, aluno: alunoId, status: 'ATIVO' });
  return true;
}
async function transferir(alunoId, de, para) {
  await carregar(); exigir('turma.escrever');
  const m = dados.matriculas.find((x) => x.aluno === alunoId && x.turma === de);
  if (m) { m.status = 'TRANSFERIDO'; m.transferido_para = para; }
  dados.matriculas.push({ turma: para, aluno: alunoId, status: 'ATIVO' });
  log('TURMA_EDITADA', 'matricula', alunoId, 'OK', { de, para });
  return true;
}

export { carregar, entrar, sair, sessao, usuarios, salvarUsuario, definirPapel,
  fontes, fases, modulos, licoes, questoes, salvarConteudo, mudarStatus, versoes,
  hinos, hino, regrasDoHinario, topicosDoMetodo, matriz,
  turmas, salvarTurma, matriculas, matricular, transferir,
  exigir, acompanha, log, guardar };
export const _interno = { get dados() { return dados; }, get sessao() { return sessaoAtual; } };
