import { html } from '../nucleo/html.js';
import { dados, modo } from '../dados/index.js';
import { definir, avisar } from '../nucleo/estado.js';
import { ir } from '../nucleo/roteador.js';

export async function telaEntrar() {
  return html`
    <div class="pagina" style="max-width:420px">
      <h1>MSAapp Violino</h1>
      <p class="mini">Plataforma de ensino de violino — MSA, método e hinário.</p>
      <section class="cartao">
        <label for="email">E-mail</label>
        <input id="email" type="email" autocomplete="username" value="aluno@msaapp">
        <label for="senha">Senha</label>
        <input id="senha" type="password" autocomplete="current-password" value="123">
        <div class="acoes"><button class="botao" id="btn-entrar" style="flex:1">Entrar</button></div>
      </section>
      ${modo === 'memoria' ? html`
      <section class="cartao">
        <h3>Modo demonstração</h3>
        <p class="mini">O banco não está configurado, então o app roda com os dados já
        extraídos das fontes, guardados neste aparelho. As contas abaixo existem só para
        experimentar os quatro perfis; a senha de todas é <b>123</b>.</p>
        <div class="rolagem"><table><tbody>
          <tr><td>admin@msaapp</td><td>Administrador</td></tr>
          <tr><td>encarregado@msaapp</td><td>Encarregado</td></tr>
          <tr><td>instrutor@msaapp</td><td>Instrutor</td></tr>
          <tr><td>aluno@msaapp</td><td>Aluno (João)</td></tr>
        </tbody></table></div>
      </section>` : ''}
    </div>`;
}

export function ligarEntrar(raiz) {
  const botao = raiz.querySelector('#btn-entrar');
  if (!botao) return;
  const entrar = async () => {
    botao.disabled = true;
    try {
      const sessao = await dados.entrar(raiz.querySelector('#email').value, raiz.querySelector('#senha').value);
      definir({ sessao });
      ir('/');
    } catch (erro) {
      avisar(erro.message, 'erro');
      botao.disabled = false;
    }
  };
  botao.addEventListener('click', entrar);
  raiz.querySelector('#senha').addEventListener('keydown', (e) => { if (e.key === 'Enter') entrar(); });
}
