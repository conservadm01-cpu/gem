-- =====================================================================
-- Estudo Musical — MSA · a tranca que NULL abria
-- =====================================================================
-- `papel_atual()` devolve NULL para quem não tem linha em `perfis` — um
-- visitante sem conta, ou uma conta do Auth cujo perfil não foi criado.
-- Com isso `tem_gestao()` também devolvia NULL, e na guarda da publicação
--
--     if not public.tem_gestao() then raise exception ...
--
-- o `not NULL` é NULL, que não é verdadeiro: o `if` não entrava e a função
-- seguia em frente. As políticas de acesso seguraram a gravação — para elas
-- NULL já vale como "não pode" —, então nada chegou a ser gravado. Mas a
-- tranca da função dependia de sorte, e tranca não se apoia em sorte.
--
-- Conserto na raiz: as duas funções de papel passam a devolver sempre
-- verdadeiro ou falso, nunca NULL. Com isso a guarda de `publicar_conteudo`
-- volta a disparar, sem precisar reescrever a função inteira.
-- =====================================================================

create or replace function public.tem_gestao()
returns boolean
language sql
stable
as $$
  select coalesce(public.papel_atual() in ('administrador', 'encarregado'), false);
$$;

create or replace function public.tem_painel()
returns boolean
language sql
stable
as $$
  select coalesce(public.papel_atual() in ('administrador', 'encarregado', 'instrutor'), false);
$$;
