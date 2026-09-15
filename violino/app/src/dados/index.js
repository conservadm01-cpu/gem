// Escolhe a implementação da camada de dados.
//
// Com o banco configurado, fala com o Supabase; sem ele, roda em memória com o
// conteúdo já extraído das fontes. As telas não sabem qual das duas está no ar.

import { conferirContrato } from './contrato.js';
import * as base from './mock.js';
import * as aprendizagem from './mock-aprendizagem.js';

const config = (window.MSA_CONFIG || {});
export const modo = (config.supabaseUrl && config.supabaseAnonKey) ? 'servidor' : 'memoria';

const emMemoria = { ...base, ...aprendizagem };

async function carregarServidor() {
  // [EM DESENVOLVIMENTO] A implementação contra o Supabase entra aqui, com a
  // mesma superfície do contrato. Enquanto não existe, o app não finge que
  // existe: avisa e segue em memória.
  console.warn('Camada de servidor ainda não implementada; seguindo em memória.');
  return emMemoria;
}

export const dados = conferirContrato(
  modo === 'servidor' ? await carregarServidor() : emMemoria,
  modo,
);
