# O banco de dados

O app funciona sem nada disto: aberto do jeito que está, ele guarda tudo no
próprio aparelho, como sempre fez. O que este diretório acrescenta é a
possibilidade de **guardar num servidor** — o progresso acompanha a troca de
celular, e o encarregado enxerga a turma de onde estiver.

## Ligar o banco em cinco passos

1. **Crie um projeto** em [supabase.com](https://supabase.com) (a camada
   gratuita dá conta de uma congregação inteira). Anote a região mais perto
   de você.

2. **Rode as migrações**, na ordem, pelo *SQL Editor* do painel do Supabase —
   cole o conteúdo de cada arquivo e execute:

   | arquivo | o que faz |
   |---|---|
   | `migrations/0001_esquema.sql`   | tipos, tabelas e índices |
   | `migrations/0002_funcoes.sql`   | papéis, criação de perfil e a junção do progresso |
   | `migrations/0003_politicas.sql` | quem enxerga o quê (Row Level Security) |
   | `migrations/0004_conteudo.sql`  | conteúdo do painel indo e voltando |

   Quem usa a [CLI do Supabase](https://supabase.com/docs/guides/cli) roda
   `supabase db push` e pula este passo.

3. **Copie as duas chaves** em *Settings → API*: a *Project URL* e a chave
   `anon`.

4. **Preencha o `config.js`** na raiz do repositório:

   ```js
   window.MSA_CONFIG = {
     supabaseUrl: 'https://xxxxxxxx.supabase.co',
     supabaseAnonKey: 'eyJhbGciOi...',
   };
   ```

5. **Crie a primeira conta** pelo próprio app, em *Guardar no servidor*. Ela
   vira **administrador** automaticamente — é a única que nasce assim. Todas
   as seguintes entram como aluno, e o administrador promove quem for
   instrutor ou encarregado.

> **A chave `anon` é pública e pode ficar no repositório.** Ela vai dentro da
> página, que qualquer pessoa consegue ler — e não dá acesso a nada sozinha:
> quem separa os dados é o `0003_politicas.sql`, do lado do servidor. A chave
> `service_role`, essa sim, **nunca** entra no `config.js`: ela ignora todas
> as políticas.

### Confirmação de e-mail

Por padrão o Supabase exige confirmar o e-mail antes do primeiro acesso. Quem
preferir que a conta já entre direto desliga isso em *Authentication →
Providers → Email → Confirm email*. O app trata os dois casos: sem confirmação
ele entra na hora, com confirmação ele avisa para clicar no link do e-mail.

## O desenho do banco

```
perfis ─┬─ progresso_fases ── (por fase: lições lidas, jogos, melhor nota)
        ├─ tentativas          cada prova feita
        ├─ questoes_usadas     para não repetir pergunta
        ├─ certificados        um por fase concluída
        └─ matriculas ── matricula_historico

metodos ── fases ─┬─ licoes
                  ├─ questoes
                  └─ jogos

turmas ─┬─ turma_conteudos     o que se estuda, na ordem
        ├─ turma_instrutores
        ├─ turma_avaliacoes    o voto de cada instrutor
        └─ niveis ── nivel_regras ── nivel_requisitos

configuracoes · instrumentos · sugestoes · cursos · auditoria
```

Duas escolhas atravessam o esquema inteiro:

**Chave de texto, não uuid do banco.** O app cria conteúdo offline com ids do
tipo `met-lq3k8-a9f2`. Mantendo esses ids como chave primária, o que foi
cadastrado sem internet sobe depois sem reescrever referência nenhuma.

**`fase_ref` em vez de chave estrangeira no progresso.** O progresso aponta
para `'1'`…`'10'` (fases do método embutido, que vive no código do app) ou
`'m:<metodo>:<fase>'` (método cadastrado). É a mesma chave que o app já usava
no aparelho, e é o que permite guardar o progresso de um conteúdo que não é
linha de tabela.

## Como os dois lados se juntam

O progresso e o conteúdo se comportam de formas diferentes, de propósito.

### Progresso: junta sozinho, sem conflito

`sincronizar_progresso(dados)` recebe o progresso do aparelho, junta com o que
está no banco e devolve o resultado — tudo numa chamada. As regras nunca
apagam esforço:

| dado | como junta |
|---|---|
| lições lidas | união |
| pontos de jogo | o maior |
| melhor nota | a maior |
| aprovado em | a data mais antiga |
| tentativas | todas, sem repetir |
| questões usadas | união |
| certificados | o de maior nota |
| xp | o maior |

Não há decisão a tomar em lugar nenhum, então dois aparelhos, ou dois dias
offline, dão sempre no mesmo resultado. É por isso que o app sobe o progresso
sozinho, sem perguntar nada.

Quem estuda primeiro e cria conta depois não perde o que fez: ao entrar, o
progresso que estava no aparelho sobe como progresso daquela conta.

### Conteúdo: sobe quando o encarregado manda

`publicar_conteudo(dados)` faz o contrário: o que está no aparelho passa a
valer no banco, **inclusive o que foi apagado**. Por isso não roda sozinha —
um aparelho desatualizado publicando no automático apagaria o trabalho de
quem cadastrou conteúdo do outro lado. No painel, é o botão *Publicar
conteúdo*, com confirmação.

Pelo mesmo motivo o app **não baixa conteúdo automaticamente para quem cuida
do painel**: baixar substitui métodos e turmas locais. Para aluno e instrutor,
que só leem, o conteúdo vem sozinho a cada abertura.

Sugestão de aluno (`enviar_sugestao`) e voto de instrutor (`votar_turma`) sobem
por funções próprias, porque nascem fora do painel — e assim ninguém assina
sugestão nem vota no lugar de outra pessoa.

## Quem enxerga o quê

| | aluno | instrutor | encarregado | administrador |
|---|---|---|---|---|
| conteúdo publicado | lê | lê | lê e escreve | lê e escreve |
| conteúdo em rascunho | — | lê | lê e escreve | lê e escreve |
| progresso próprio | lê e escreve | lê e escreve | lê e escreve | lê e escreve |
| progresso dos outros | — | lê | lê | lê |
| turmas e matrículas | a própria | lê | lê e escreve | lê e escreve |
| votar na turma | — | sim | — | — |
| auditoria | — | — | lê | lê |
| promover contas | — | — | — | sim |

Visitante sem conta não lê nada: todas as políticas são `to authenticated`.

Três detalhes que não aparecem na tabela:

- **O papel nunca vem do cadastro.** Quem se inscreve entra como aluno, sempre.
  Aceitar um papel declarado na inscrição deixaria qualquer visitante se
  nomear administrador. A única exceção é a primeira conta do sistema.
- **A coluna `perfil` tem trava própria**, no gatilho `proteger_papel`. As
  políticas trabalham por linha, então sem isso um aluno editando o próprio
  nome editaria o próprio papel junto.
- **A auditoria só cresce.** Não há política de `update` nem de `delete`, nem
  para o administrador: uma trilha que pode ser reescrita não serve de trilha.

## Trazer para a nuvem quem já usava o app

Uma instalação antiga conhece as pessoas por ids locais (`alu-teste`,
`ins-lq3k8…`), e as matrículas e o histórico apontam para esses ids. A coluna
`perfis.conta_local` é a ponte: com ela preenchida, `publicar_conteudo`
encontra o dono de cada matrícula.

Cada pessoa liga a própria conta pelo app, em *Guardar no servidor → Conta
antiga deste aparelho*. Quando uma matrícula sobe sem dono correspondente, a
publicação não falha em silêncio: ela volta com um aviso dizendo qual conta
não foi encontrada.
