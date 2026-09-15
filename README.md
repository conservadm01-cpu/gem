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

**Relatório de acertos e erros:** cada questão nasce de um gerador — e o
gerador é o assunto. Guardando o acerto ou erro de cada uma, o app diz não só
"tirou 60" mas em que o aluno tropeça: *ordem dos acidentes, 85% de erro*. O
aluno vê o próprio desempenho em **Meus acertos e erros**; com o banco ligado,
o encarregado vê a turma somada em **Relatório da turma**. Um assunto só entra
no ranking a partir de 4 questões respondidas — antes disso o percentual diria
mais sobre o acaso do que sobre a dificuldade.

**Perfis:** aluno, instrutor e encarregado. O painel permite cadastrar métodos,
fases, lições e questões próprias, montar turmas e níveis, acompanhar o
progresso, avaliar instrutores e emitir certificados para impressão.

**Avaliação com semente:** a mesma semente devolve sempre a mesma prova, o que
permite refazer uma avaliação exatamente como ela caiu e conferir um
certificado sem guardar as perguntas inteiras.

## Onde os dados ficam

**Do jeito que vem, tudo fica no aparelho** (`localStorage`) e nada é enviado
para servidor nenhum. Há exportação e importação do progresso pelo painel, para
trocar de aparelho ou fazer cópia de segurança.

**Ligando um banco**, o progresso passa a acompanhar a pessoa: ela estuda no
celular, entra pelo computador e continua de onde parou, e o encarregado
enxerga a turma de onde estiver. É opcional e não muda nada de quem não ligar
— sem internet, o app continua funcionando igual e sobe o que foi estudado
quando a rede voltar.

O passo a passo está em [`supabase/README.md`](supabase/README.md): criar o
projeto, rodar as quatro migrações e preencher o `config.js`. O esquema, as
políticas de acesso e as regras de junção também estão explicados lá.

O app não busca nada de terceiros. O [pdf.js](https://mozilla.github.io/pdf.js/),
usado para ler PDF na geração de cursos, vem junto em `vendor/` — antes vinha
de uma CDN, e era aí que a leitura de PDF parava quando um bloqueador de
anúncios ou uma rede de trabalho barrava o domínio de fora.

## Como usar

**Direto do arquivo:** baixe o `index.html` e abra no navegador. Funciona
offline.

**Publicado no GitHub Pages:** o fluxo de trabalho em
`.github/workflows/pages.yml` publica o repositório inteiro a cada push no
branch padrão. Antes da primeira publicação é preciso ligar o Pages uma vez em
**Settings → Pages**, escolhendo **GitHub Actions** como origem — o token do
fluxo não tem permissão para criar o site sozinho. Feito isso, o endereço fica
em `https://<usuario>.github.io/<repositorio>/`.

## Estrutura

```
index.html   o aplicativo inteiro (HTML, CSS e JavaScript)
config.js    endereço do banco; vazio = só neste aparelho
vendor/      pdf.js, para ler PDF sem depender de CDN
supabase/    migrações do banco e o passo a passo para ligá-lo
.nojekyll    impede o Jekyll de mexer nos arquivos publicados
.github/workflows/pages.yml   publicação automática no GitHub Pages
```

O JavaScript é organizado em módulos internos (`__modulos`): sorteio com
semente, armazenamento do progresso, motor de questões, jogos, teclado,
análise de documento e montagem de curso, ligação com o servidor e
sincronização, telas e roteamento.
