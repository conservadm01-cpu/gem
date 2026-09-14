# Estudo Musical — MSA

Aplicativo de estudo de teoria musical, feito para estudar no celular: alvo de
toque grande, texto legível ao ar livre e contraste que sobrevive à tela do
ônibus. Tudo em um único arquivo `index.html`, sem instalação e sem servidor.

## O que tem dentro

**10 fases**, cada uma com lições, avaliação e jogos:

| # | Fase | Assunto |
|---|------|---------|
| 1 | O som e a música | Propriedades do som, notas musicais |
| 2 | A escrita musical | Pentagrama, claves, figuras e pausas |
| 3 | Ritmo, pulsação e compasso | Fórmulas simples, tempos fortes e condução |
| 4 | Metrônomo, ponto de aumento e tercinas | Velocidade, prolongamento e divisão especial |
| 5 | Tons, semitons e acidentes | Sustenido, bemol, bequadro e enarmonia |
| 6 | Escalas maiores e armaduras | T T st T T T st, sustenidos e bemóis |
| 7 | Tonalidade, intervalos e dinâmica | Maior e menor, distâncias e volume |
| 8 | Compasso composto e subdivisão | 6/8, 9/8, 12/8 e a divisão do tempo |
| 9 | Síncopa, contratempo e ritmos iniciais | Tético, anacrústico e acéfalo |
| 10 | Interpretação, andamento e forma | Termos, agógica, frase e semifrase |

**Jogos:** memória, leitura no pentagrama, fecha o compasso, teclado, ouvido
(intervalos e alturas), pulso/metrônomo e armadura de clave.

**Perfis:** aluno, instrutor e encarregado. O painel permite cadastrar métodos,
fases, lições e questões próprias, montar turmas e níveis, acompanhar o
progresso, avaliar instrutores e emitir certificados para impressão.

**Avaliação com semente:** a mesma semente devolve sempre a mesma prova, o que
permite refazer uma avaliação exatamente como ela caiu e conferir um
certificado sem guardar as perguntas inteiras.

## Privacidade

O progresso fica guardado no próprio aparelho (`localStorage`). Nada é enviado
para servidor nenhum. Há exportação e importação do progresso pelo painel, para
trocar de aparelho ou fazer cópia de segurança.

A única busca externa do app é o [pdf.js](https://mozilla.github.io/pdf.js/)
pelo cdnjs, carregado só quando se importa um PDF para gerar um curso. Sem
internet, o resto do app continua funcionando normalmente.

## Como usar

**Direto do arquivo:** baixe o `index.html` e abra no navegador. Funciona
offline.

**Publicado no GitHub Pages:** o fluxo de trabalho em
`.github/workflows/pages.yml` publica o repositório inteiro a cada push no
branch padrão. Para ligar, vá em **Settings → Pages** e escolha **GitHub
Actions** como origem. O endereço fica em
`https://<usuario>.github.io/<repositorio>/`.

## Estrutura

```
index.html   o aplicativo inteiro (HTML, CSS e JavaScript)
.nojekyll    impede o Jekyll de mexer nos arquivos publicados
.github/workflows/pages.yml   publicação automática no GitHub Pages
```

O JavaScript é organizado em módulos internos (`__modulos`): sorteio com
semente, banco de dados do progresso, motor de questões, jogos, teclado,
análise de documento e montagem de curso, telas e roteamento.
