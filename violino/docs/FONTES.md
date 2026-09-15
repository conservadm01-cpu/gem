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
| Hinário CCB nº 5 (cordas) | **Ausente** | Nada. O módulo do Hinário está bloqueado. |

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

## Violino e Hinário

Sem os arquivos, nada de conteúdo será escrito nesses dois módulos. O que será
construído é a **estrutura**: as tabelas, a taxonomia de indexação pedida no
prompt (partes do violino, arco, postura, mão esquerda, arcadas, cordas
soltas, escalas, posições…; e número, tonalidade, compasso, arcadas,
ritornello, final por hino), os tipos de questão específicos de cordas
(identificação de corda, de dedo, de arcada) e o importador que ingere os PDFs
quando chegarem.

Toda linha desses módulos nasce com `status = RASCUNHO` e
`observacao = 'VALIDAÇÃO NECESSÁRIA — aguardando a fonte'`.

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
