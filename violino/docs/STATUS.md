# MSAapp Violino — status da versão

Classificação conforme a seção 50 do código mestre. Nada aqui está marcado
acima do que foi efetivamente testado.

| Recurso | Situação |
|---|---|
| Arquitetura | **[IMPLEMENTADO]** |
| Banco de dados | **[IMPLEMENTADO]** — 32 tabelas, 67 políticas, 19 funções |
| Login | **[IMPLEMENTADO]** |
| RBAC | **[IMPLEMENTADO]** — no banco e espelhado na interface |
| MSA | **[IMPLEMENTADO]** — 10 fases, 39 lições, 69 assuntos, 1319 variantes |
| Hinário | **[IMPLEMENTADO]** — 385 hinos, 6 coros, 10 regras; metadados **[EM DESENVOLVIMENTO]** (7 de 385) |
| Método Schmoll | **[PENDENTE DE FONTE]** — estrutura dos 10 módulos criada, sem conteúdo |
| Questões | **[IMPLEMENTADO]** — motor com recusa por campo ausente |
| Não repetição | **[IMPLEMENTADO]** — assinatura + proximidade semântica |
| Analytics | **[IMPLEMENTADO]** — por assunto, fonte, habilidade e fase |
| Dashboard | **[IMPLEMENTADO]** — instrutor com modo professor; aluno com progresso |
| Vídeos | **[EM DESENVOLVIMENTO]** — dados e permissões prontos, sem tela |
| Perguntas | **[EM DESENVOLVIMENTO]** — dados e permissões prontos, sem tela |
| Gamificação | **[IMPLEMENTADO]** — 7 medalhas com critério objetivo |
| Certificados | **[EM DESENVOLVIMENTO]** — tabela e regras prontas, sem emissão |
| Importação de fontes | **[PENDENTE]** |
| Versionamento | **[IMPLEMENTADO]** — no banco, por gatilho |
| Logs | **[IMPLEMENTADO]** — 27 ações, trilha só de inserção |
| Backup | **[IMPLEMENTADO]** — JSON e CSV |
| Testes | **[IMPLEMENTADO]** — 18 no banco, 18 no navegador |
| Jogos | **[PENDENTE]** |
| Camada de servidor no app | **[EM DESENVOLVIMENTO]** — contrato pronto, implementação Supabase pendente |

## Decisão técnica: sem etapa de build

O app são módulos ES nativos, servidos como arquivos. Um projeto com bundler
exigiria `npm install` e `npm run build` a cada alteração, o que a operação
deste projeto não comporta. Módulos ES dão a mesma separação de
responsabilidades, publicam copiando arquivo e não envelhecem junto com uma
cadeia de dependências. É a escolha mais simples e sustentável entre as duas,
que é o critério da seção 52.

A separação exigida existe: `nucleo` (html, estado, roteador), `dados`
(contrato + implementações), `dominio` (regras que não dependem de tela),
`telas`, `ui`.

## A camada de dados tem contrato

`dados/contrato.js` lista os 40 métodos que qualquer implementação precisa ter,
e a conferência roda na carga. Hoje existe a implementação em memória; a de
servidor entra sem tocar em tela nenhuma. É o que permite o modo demonstração
não virar reescrita depois.

O modo em memória **aplica as mesmas regras de acesso** que o banco aplica —
não é maquete. Um aluno que tente listar usuários é recusado nos dois modos.

## Erros encontrados e corrigidos

1. **`fases.id` convertido para inteiro** em duas funções de indicador. O id é
   texto (`'f1'`); o número da fase é outra coluna. Quebrava "pronto para
   avançar".
2. **`insert … returning` no log** exige política de leitura no Postgres, e o
   registro falhava justamente para o aluno — quem mais gera evento. A função
   virou `security definer` com autoria fixada em `auth.uid()`.
3. **Montagem do template fora de ordem.** A função `html` colocava o valor
   interpolado depois do trecho seguinte, embaralhando o HTML sem erro nenhum:
   o menu ficou sem links e as tabelas quebraram. Foi o defeito mais sério,
   porque não gera exceção — só resultado errado.
4. **Aviso de ação nunca aparecia**, porque nada redesenhava quando o estado
   mudava. Erro de login falhava em silêncio.
5. **Fonte duplicada no relatório:** o gerador usava o nome por extenso do
   registro ("Hinário CCB nº 5") como identificador, e a mesma fonte aparecia
   duas vezes. O identificador passou a ser parâmetro obrigatório.

## Como testar

```
cd violino/app && python3 -m http.server 8000
```

Abra `http://localhost:8000`. Contas de demonstração, senha `123`:
`admin@msaapp`, `encarregado@msaapp`, `instrutor@msaapp`, `aluno@msaapp`.

O banco fica em `violino/supabase/`: cinco migrações e a carga inicial.

## Próximo passo recomendado

Telas de vídeo e perguntas — são as duas que fecham o ciclo pedagógico do
princípio de ouro (aluno grava → instrutor avalia → vira dado no dashboard) e
já têm dados e permissões prontos.

Depois: a camada de servidor, para sair do modo demonstração.

**Nada do Método Schmoll foi incorporado.** O PDF original não foi analisado —
só a camada textual auxiliar, que não substitui a fonte.
