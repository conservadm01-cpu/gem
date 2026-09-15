# Registro de fontes — MSAapp Violino

Auditoria do que foi entregue ao projeto, feita antes de escrever qualquer
código. A regra de ouro nº 1 diz "não inventar conteúdo atribuído às fontes",
e é por isso que este arquivo vem primeiro: ele delimita o que pode ser
construído com fidelidade e o que está bloqueado.

## O que existe

| Fonte | Situação | O que dá para fazer |
|---|---|---|
| `msaapp.html` | **Completo** | Lido inteiro. Arquitetura, módulos, banco de questões, fases, jogos, certificados, armazenamento, não repetição e roteador estão mapeados abaixo. |
| MSA (livro) | **Parcial — 9 páginas de 158** | Ver abaixo. |
| Método de Violino (Schmoll CCB) | **Ausente** | Nada. Todo o currículo de violino está bloqueado. |
| Hinário CCB nº 5 | **Parcial — ver abaixo** | Índice de 364 hinos e as 10 regras de utilização, extraídos com fidelidade. Falta a partitura de cordas. |

## O MSA entregue está truncado

Os cinco PDFs têm nomes que prometem faixas de 30 páginas, mas cada arquivo
contém **2 páginas digitalizadas**, não 30. São imagens (150–300 dpi), sem
camada de texto.

| Arquivo | Páginas no PDF | Páginas do livro |
|---|---|---|
| `MSA_1A30.pdf` | 2 | capa · 31 |
| `MSA_31A60.pdf` | 2 | 32 · 61 |
| `MSA_61A90.pdf` | 2 | 62 · 91 |
| `MSA_91A120.pdf` | 2 | 92 · 121 |
| `MSA_121A158.pdf` | 2 | 122 · (sem numeração) |

Ou seja: chegaram as páginas **31, 32, 61, 62, 91, 92, 121 e 122**, mais a
capa. As outras 149 não vieram. O padrão — primeira e última página de cada
faixa — sugere que a exportação salvou só as bordas de cada intervalo.

**Para destravar:** reexportar o MSA inteiro, de preferência num arquivo só.
Se o gerador de PDF tiver opção de intervalo, confira que ele está salvando
todas as páginas do intervalo e não apenas a primeira e a última.

## O que o app já traz de MSA, e é aproveitável

O `msaapp.html` carrega um currículo derivado do MSA por quem construiu o app,
com referência de página em tudo. Isso é conteúdo verificável e rastreável, e
foi conferido contra a única página que dá para ler por inteiro (pág. 32,
exercícios de leitura rítmica com a sílaba "TA" e o tratamento das pausas —
bate com a fase 3 do app).

- 10 fases, cobrindo as páginas 9 a 140
- 39 lições, cada uma com a página do livro
- 20 jogos
- 69 geradores de questão, com 92 referências de página e **1319 variantes**

A matriz pedagógica em `violino/dados/matriz-pedagogica.csv` foi montada
**apenas** desse material. Nenhuma linha foi inventada.

### O que nessa matriz é do MSA e o que é do sistema

Distinção que precisa ficar explícita, para ninguém atribuir ao livro o que
não está nele:

| Coluna | Origem |
|---|---|
| fonte, fase, modulo, licao, assunto, subassunto, pagina | **MSA**, via o currículo do app |
| ID, instrumento, tipo_de_atividade, tipo_de_questao, tags | estrutura do sistema |
| **habilidade, dificuldade, objetivo, pre_requisito** | **classificação do sistema — revisável** |

`habilidade` e `dificuldade` não existem no MSA: são classificação pedagógica
proposta pelo sistema, para alimentar o mapa de dificuldades. Devem passar por
revisão do encarregado antes de valerem como oficiais.

## Hinário CCB nº 5 — o que veio e o que falta

Chegaram 4 PDFs de 100 páginas (400 no total). A música é imagem digitalizada,
mas **o cabeçalho de cada hino tem camada de texto**, e a seção de instruções
também. Daí saíram dois conjuntos de dados, ambos verificáveis:

**`violino/dados/hinario-indice.csv`** — **385 hinos e 6 coros**. O hinário
vai até o hino 480, seguido do índice geral e dos coros, numerados à parte.
Cada linha traz número, nome, arquivo e página.

Cobertura: hinos **1 a 364** e **460 a 480**; coros **1 a 6**. **Faltam os
hinos 365 a 459** — 95 no total, que não vieram em nenhum arquivo. Os nomes
dos arquivos não correspondem ao conteúdo (o chamado `301_a_400` termina no
364; o chamado `501-535` começa no 460), então vale conferir pelo conteúdo, e
não pelo nome, o que ainda falta exportar.

**`violino/dados/hinario-regras.json`** — as 10 regras da seção *Instruções de
utilização do hinário de música para instrumentos de cordas*, transcritas
literalmente. Três são específicas de violino:

- **Vozes:** "Os violinos devem executar a voz do soprano, as violas a voz do
  tenor e os violoncelos a voz do baixo. Quando houver necessidade e a critério
  do encarregado de orquestra, alguns violinos poderão ser solicitados a
  executar a voz do contralto."
- **Oitava:** "Adota-se como padrão nos cultos em geral que os violinos toquem
  uma oitava acima — salvo se, excepcionalmente, o encarregado de orquestra
  solicitar que se toque como está escrito."
- **Arcadas:** "Quando houver arcada somente sobre a nota do soprano, essa
  arcada também se aplica ao contralto. Da mesma forma, quando houver arcada
  somente sobre a nota do tenor, essa arcada também se aplica ao baixo."

### Três ressalvas

**1. É a edição de órgão — decisão tomada: seguir com ela.** Os arquivos se
chamam `orgao` e a partitura confere: três pautas com colchete, no formato de
órgão. A seção de instruções, porém, é a de **cordas**, e fala da "escrita do
tenor na clave de dó na 3ª linha, específica para as violas", que não aparece
nessas páginas.

O responsável pelo projeto decidiu seguir com esta edição. O que isso implica,
para ficar registrado:

- **Vale:** as 10 regras de utilização; o índice; e os metadados de cada hino
  — armadura, fórmula de compasso, faixa de metrônomo e compositor. Esses
  quatro são do hino, não da edição: a armadura e o compasso de um hino são os
  mesmos em qualquer arranjo, e a faixa de metrônomo é a que o hinário
  estabelece para todos os instrumentos.
- **Não vale:** os **sinais de arcada por hino**. Eles só existem na edição de
  cordas — é o que a regra HIN-R10 descreve. O campo `arcadas` fica vazio, e
  continuará vazio enquanto essa edição não chegar. O app não deve inventar
  arcada nenhuma.

**2. Faltam os hinos 365 a 459.** Os arquivos cobrem 1–364 e 460–480. O
hinário termina no 480 (confirmado pelo índice geral e pelos coros que vêm
depois), então o buraco é de 95 hinos no meio da coleção.

**3. Tonalidade, compasso e andamento estão só na imagem.** A camada de texto
dá número e nome. O resto — armadura, fórmula de compasso, marcação de
metrônomo (ex.: no hino 41, `♪ = 120 - 144`, 9/8, três sustenidos) — está
desenhado na partitura. Dá para extrair numa passagem de leitura visual página
a página; são 364 páginas, então fica como etapa própria, e até lá esses
campos ficam `VALIDAÇÃO NECESSÁRIA` no índice.

## Método de Violino

Sem o arquivo, nada de conteúdo será escrito nesse módulo. O que será
construído é a **estrutura**: as tabelas, a taxonomia de indexação pedida no
prompt (partes do violino, arco, postura, mão esquerda, arcadas, cordas
soltas, escalas, posições…; e número, tonalidade, compasso, arcadas,
ritornello, final por hino), os tipos de questão específicos de cordas
(identificação de corda, de dedo, de arcada) e o importador que ingere os PDFs
quando chegarem.

Toda linha desses módulos nasce com `status = RASCUNHO` e
`observacao = 'VALIDAÇÃO NECESSÁRIA — aguardando a fonte'`.

No Hinário, o índice e as regras já estão prontos para virar conteúdo; o que
ainda depende de fonte é a partitura de cordas e os metadados de cada hino.

## Análise do app existente (itens 1 a 10 do prompt)

| Item | O que foi encontrado |
|---|---|
| Arquitetura | Arquivo único, 9,3 mil linhas, com registro de módulos `__modulos` |
| Módulos | 24: aleatorio, musica, notacao, audio, download, conteudo/fases, conteudo/geradores, armazenamento, quiz, certificado, jogos, permissoes, conteudo/editavel, gerador-auto, importador, progressao, auditoria, instrumentos, cursos, geradorConteudo, relatorio, nuvem, sincronia, app |
| Banco de questões | 69 geradores × variantes = 1319 questões distintas, montadas na hora |
| Fases | `FASES`, 10 fases fixas + fases de métodos cadastrados (`m:metodo:fase`) |
| Jogos | 7 tipos: memória, pentagrama, ritmo, teclado, ouvido, pulso, armadura |
| Certificados | SVG desenhado no app, com código de verificação derivado de nome+fase+data |
| Armazenamento | `localStorage` em 5 chaves + Supabase (Postgres com RLS), junção sem conflito |
| Não repetição | Assinatura `gerador#chave(variante)`; as usadas são descontadas do sorteio |
| Roteador | Hash (`#/fase/1/licao/0`), despacho por `partes[]` dentro de `desenhar()` |

**O que vale reaproveitar:** os geradores com assinatura e a regra de não
repetição, a junção de progresso sem conflito, o esquema de RLS por perfil, o
certificado em SVG, os jogos e a notação musical desenhada em SVG.

**O que não vale:** o arquivo único. O prompt pede separação de frontend,
backend, banco e arquivos — e o volume de funcionalidades pedido não cabe num
HTML só.
