"""
Exhaustive back-door check for the fixed DAG (Claim 1). No dependencies.

DAG: W->X, W->Y, A->X, A->Y, L->X, X->M1, M1->Y, X->M2, M2->Y

Enumerates EVERY simple path between X and Y, classifies each as back-door or
causal, and tests d-separation under a candidate Z. Also runs the A-refinement
(A split into A_ability, A_motivation, A_procrast, A_difficulty).

Run:  python dag_check.py
"""
from itertools import chain

BASE = [("W", "X"), ("W", "Y"), ("A", "X"), ("A", "Y"), ("L", "X"),
        ("X", "M1"), ("M1", "Y"), ("X", "M2"), ("M2", "Y")]

REFINED = [("W", "X"), ("W", "Y"), ("L", "X"),
           ("X", "M1"), ("M1", "Y"), ("X", "M2"), ("M2", "Y")] + list(chain.from_iterable(
    [(a, "X"), (a, "Y")] for a in
    ["A_ability", "A_motivation", "A_procrast", "A_difficulty"]))


def nodes(E):
    return sorted({v for e in E for v in e})


def descendants(E, x):
    """All nodes reachable from x by directed edges (x excluded)."""
    seen, stack = set(), [x]
    while stack:
        u = stack.pop()
        for a, b in E:
            if a == u and b not in seen:
                seen.add(b)
                stack.append(b)
    return seen


def simple_paths(E, s, t):
    """All simple undirected paths s..t, as node lists."""
    adj = {n: set() for n in nodes(E)}
    for a, b in E:
        adj[a].add(b)
        adj[b].add(a)
    out, stack = [], [[s]]
    while stack:
        p = stack.pop()
        for nxt in adj[p[-1]]:
            if nxt in p:
                continue
            if nxt == t:
                out.append(p + [t])
            else:
                stack.append(p + [nxt])
    return sorted(out, key=len)


def draw(E, p):
    """Render a path with its arrow directions."""
    s = p[0]
    for u, v in zip(p, p[1:]):
        s += (" -> " if (u, v) in E else " <- ") + v
    return s


def is_backdoor(E, p):
    """True iff the first edge points INTO X (i.e. path starts X <- ...)."""
    return (p[1], p[0]) in E


def blocked(E, p, Z):
    """d-separation: blocked iff some non-endpoint node blocks the path."""
    de = {n: descendants(E, n) for n in nodes(E)}
    for i in range(1, len(p) - 1):
        u, m, v = p[i - 1], p[i], p[i + 1]
        collider = (u, m) in E and (v, m) in E
        if collider:
            if m not in Z and not (de[m] & Z):
                return True, f"collider at {m}, {m} and its descendants not in Z"
        elif m in Z:
            kind = "chain" if ((u, m) in E) != ((v, m) in E) else "fork"
            return True, f"{kind} at {m}, {m} in Z"
    return False, "open"


def report(E, Z, tag):
    ps = simple_paths(E, "X", "Y")
    de_X = descendants(E, "X")
    print(f"\n{'=' * 78}\n{tag}   Z = {{{', '.join(sorted(Z))}}}\n{'=' * 78}")
    print(f"descendants of X = {{{', '.join(sorted(de_X))}}}")
    bad = sorted(Z & de_X)
    print(f"condition (i)  no node of Z is a descendant of X : "
          f"{'PASS' if not bad else 'FAIL -> ' + ', '.join(bad)}")
    print(f"\n{len(ps)} simple path(s) between X and Y:")
    print(f"  {'#':<3}{'path':<34}{'back-door?':<12}{'blocked by Z?':<15}why")
    ok = True
    for i, p in enumerate(ps, 1):
        bd = is_backdoor(E, p)
        blk, why = blocked(E, p, Z)
        if bd and not blk:
            ok = False
        print(f"  {i:<3}{draw(E, p):<34}{'YES' if bd else 'no':<12}"
              f"{('YES' if blk else 'NO'):<15}{why}")
    print(f"\ncondition (ii) all back-door paths blocked : {'PASS' if ok else 'FAIL'}")
    verdict = ok and not bad
    print(f"VERDICT: Z {'SATISFIES' if verdict else 'DOES NOT SATISFY'} "
          f"the back-door criterion relative to (X, Y)")
    causal_open = [draw(E, p) for p in ps if not is_backdoor(E, p) and not blocked(E, p, Z)[0]]
    print(f"causal paths left open (these carry the estimated effect): "
          f"{causal_open if causal_open else 'NONE - total effect is not recovered'}")
    return verdict


report(BASE, {"W", "A"}, "BASE DAG, Z = {W, A}")
report(BASE, {"W", "A", "M1"}, "BASE DAG, Z' = {W, A, M1}")
report(BASE, {"W", "A", "L"}, "BASE DAG, Z u {L}   (section 3a: is L back-door relevant?)")
report(REFINED, {"W", "A_ability", "A_motivation", "A_procrast", "A_difficulty"},
       "A-REFINED DAG (section 3b: invariance)")
report(REFINED, {"W", "A_ability", "A_motivation", "A_procrast"},
       "A-REFINED DAG, one sub-node OMITTED (shows refinement is not free)")

# section 3a, hidden-confounding failure case: add L -> Y
report(BASE + [("L", "Y")], {"W", "A"},
       "BASE DAG + hidden edge L -> Y   (section 3a: when omitting L fails)")
