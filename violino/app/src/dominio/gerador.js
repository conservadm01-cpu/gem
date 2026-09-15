// Motor de questões.
//
// A regra que governa este arquivo: um molde só produz questão quando TODOS os
// campos que ele exige existem no registro da fonte. Faltou campo, não sai
// questão — não sai questão com lacuna, nem com palpite. É assim que "não
// inventar" deixa de depender de disciplina e passa a depender do código.
//
// Toda questão gerada carrega fonte e referência. Sem referência, o motor
// recusa a questão.

import { assinar, sortearIneditas } from './assinatura.js';

/** Embaralha sem alterar o original. A ordem não entra na assinatura. */
function embaralhar(lista, aleatorio = Math.random) {
  const copia = [...lista];
  for (let i = copia.length - 1; i > 0; i--) {
    const j = Math.floor(aleatorio() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
}

/** Distratores: valores reais de outros registros, nunca inventados. */
function distratores(valor, universo, quantos, aleatorio) {
  const outros = [...new Set(universo.filter((v) => v && v !== valor))];
  return embaralhar(outros, aleatorio).slice(0, quantos);
}

// ------------------------------------------------------------------ moldes

// `exige` lista os campos obrigatórios do registro. `universo` diz de onde
// saem os distratores.
export const MOLDES_HINARIO = [
  {
    id: 'hin.compasso',
    tipo: 'IDENTIFICAR_COMPASSO',
    habilidade: 'APLICACAO',
    dificuldade: 2,
    exige: ['numero', 'nome', 'compasso'],
    campoResposta: 'compasso',
    montar: (h) => ({
      enunciado: `Qual é a fórmula de compasso do hino ${h.numero} — "${h.nome}"?`,
      explicacao: `O hino ${h.numero} está escrito em ${h.compasso}.`,
    }),
  },
  {
    id: 'hin.armadura',
    tipo: 'IDENTIFICAR_TONALIDADE',
    habilidade: 'ANALISE',
    dificuldade: 3,
    exige: ['numero', 'nome', 'armadura'],
    campoResposta: 'armadura',
    montar: (h) => ({
      enunciado: `Quantos acidentes traz a armadura do hino ${h.numero} — "${h.nome}"?`,
      explicacao: `A armadura do hino ${h.numero} tem ${h.armadura}.`,
    }),
  },
  {
    id: 'hin.andamento',
    tipo: 'MULTIPLA_ESCOLHA',
    habilidade: 'COMPREENSAO',
    dificuldade: 2,
    exige: ['numero', 'nome', 'andamento_min', 'andamento_max'],
    resposta: (h) => `${h.andamento_min} a ${h.andamento_max}`,
    universo: (todos) => todos.filter((x) => x.andamento_min).map((x) => `${x.andamento_min} a ${x.andamento_max}`),
    montar: (h) => ({
      enunciado: `Qual é a faixa de metrônomo indicada para o hino ${h.numero} — "${h.nome}"?`,
      explicacao: `O hinário indica ${h.andamento_min} a ${h.andamento_max}. A recomendação é ficar na média entre o mínimo e o máximo.`,
    }),
  },
  {
    id: 'hin.compositor',
    tipo: 'MULTIPLA_ESCOLHA',
    habilidade: 'MEMORIZACAO',
    dificuldade: 4,
    exige: ['numero', 'nome', 'compositor'],
    campoResposta: 'compositor',
    montar: (h) => ({
      enunciado: `De quem é a música do hino ${h.numero} — "${h.nome}"?`,
      explicacao: `O hino ${h.numero} é de ${h.compositor}.`,
    }),
  },
];

/** Questões a partir das regras do hinário, que são texto literal da fonte. */
export const MOLDES_REGRA = [
  {
    id: 'hin.regra',
    tipo: 'MULTIPLA_ESCOLHA',
    habilidade: 'MEMORIZACAO',
    dificuldade: 2,
    exige: ['id', 'assunto', 'texto'],
    montar: (r) => ({
      enunciado: `Segundo as instruções do Hinário, o que se aplica a "${r.assunto.toLowerCase()}"?`,
      explicacao: r.texto,
    }),
    resposta: (r) => r.texto,
    universo: (todas) => todas.map((x) => x.texto),
  },
];

// ------------------------------------------------------------------ motor

function gerarDe(registro, molde, universo, aleatorio, fonteId) {
  const faltando = molde.exige.filter((c) => registro[c] === undefined || registro[c] === null || registro[c] === '');
  if (faltando.length) return { recusada: true, motivo: `VALIDAÇÃO NECESSÁRIA — falta ${faltando.join(', ')}` };

  const resposta = molde.resposta ? molde.resposta(registro) : registro[molde.campoResposta];
  if (!resposta) return { recusada: true, motivo: 'VALIDAÇÃO NECESSÁRIA — sem resposta na fonte' };

  const pool = molde.universo ? molde.universo(universo) : universo.map((x) => x[molde.campoResposta]);
  const erradas = distratores(resposta, pool, 3, aleatorio);
  if (erradas.length < 2) return { recusada: true, motivo: 'VALIDAÇÃO NECESSÁRIA — sem alternativas suficientes na fonte' };

  const { enunciado, explicacao } = molde.montar(registro);
  const alternativas = embaralhar([resposta, ...erradas], aleatorio);

  return {
    id: `${molde.id}:${registro.numero ?? registro.id}`,
    molde: molde.id,
    tipo: molde.tipo,
    habilidade: molde.habilidade,
    dificuldade: molde.dificuldade,
    enunciado,
    alternativas,
    resposta,
    explicacao,
    // O identificador da fonte vem de fora, nunca do registro: o índice
    // guarda o nome por extenso ("Hinário CCB nº 5"), e misturar nome com
    // identificador faria a mesma fonte aparecer duas vezes no relatório.
    fonte: fonteId,
    referencia: registro.pdf_pagina
      ? `Hinário CCB nº 5, ${registro.arquivo || ''} p. ${registro.pdf_pagina}`
      : (registro.referencia || 'Hinário CCB nº 5, instruções de utilização'),
    assinatura: assinar({
      conteudo: molde.id,
      variante: String(registro.numero ?? registro.id),
      enunciado,
      alternativas,
      dificuldade: molde.dificuldade,
    }),
  };
}

/**
 * Gera o universo de questões possíveis a partir de registros de uma fonte.
 * Devolve também as recusas, para o painel enxergar onde falta dado — é o
 * inverso de esconder a lacuna.
 */
export function universoDeQuestoes(registros, moldes, { fonteId, aleatorio = Math.random } = {}) {
  if (!fonteId) throw new Error('O gerador exige o identificador da fonte.');
  const questoes = [];
  const recusadas = [];
  for (const registro of registros) {
    for (const molde of moldes) {
      const r = gerarDe(registro, molde, registros, aleatorio, fonteId);
      if (r.recusada) recusadas.push({ registro: registro.numero ?? registro.id, molde: molde.id, motivo: r.motivo });
      else questoes.push(r);
    }
  }
  return { questoes, recusadas };
}

/** Monta uma prova sem repetir para quem já respondeu. */
export function montarProva({ universo, usadas = [], quantidade = 10, aleatorio = Math.random }) {
  return sortearIneditas(universo, usadas, quantidade, aleatorio);
}
