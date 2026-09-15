// Estado da aplicação: sessão, perfil e avisos. Quem quiser saber de mudança
// se inscreve; ninguém lê variável global de fora.

const ouvintes = new Set();

const estado = {
  sessao: null,        // { id, nome, perfil, email }
  carregando: false,
  aviso: null,         // { tipo: 'erro'|'ok', texto }
};

export const ler = () => estado;

export function definir(mudanca) {
  Object.assign(estado, mudanca);
  ouvintes.forEach((f) => { try { f(estado); } catch (erro) { console.error(erro); } });
}

export function aoMudar(f) {
  ouvintes.add(f);
  return () => ouvintes.delete(f);
}

export const avisar = (texto, tipo = 'ok') => definir({ aviso: { texto, tipo } });
export const limparAviso = () => definir({ aviso: null });
