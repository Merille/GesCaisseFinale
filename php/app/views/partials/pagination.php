<?php
// Pagination d'une liste. Variables : $page, $pages, $total, $parPage, $route, $params, $libelle.
if ($total === 0) {
    return;
}
$debut = ($page - 1) * $parPage + 1;
$fin = min($page * $parPage, $total);
$lienPage = fn(int $n) => url($route, $params + ['page' => $n > 1 ? $n : null]);

// Pages affichées : la première, la dernière et deux autour de la page courante.
$numeros = array_unique(array_filter(
    [1, $page - 2, $page - 1, $page, $page + 1, $page + 2, $pages],
    fn($n) => $n >= 1 && $n <= $pages
));
sort($numeros);
?>
<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-3">
    <div class="small text-muted"><?= h($libelle ?? 'Lignes') ?> <?= $debut ?> à <?= $fin ?> sur <?= $total ?></div>
    <?php if ($pages > 1): ?>
    <nav aria-label="Pagination">
        <ul class="pagination pagination-sm mb-0">
            <li class="page-item <?= $page === 1 ? 'disabled' : '' ?>">
                <a class="page-link" href="<?= h($lienPage($page - 1)) ?>" aria-label="Page précédente">&laquo;</a>
            </li>
            <?php $precedent = 0; foreach ($numeros as $n): ?>
                <?php if ($n - $precedent > 1): ?>
                    <li class="page-item disabled"><span class="page-link">…</span></li>
                <?php endif; ?>
                <li class="page-item <?= $n === $page ? 'active' : '' ?>" <?= $n === $page ? 'aria-current="page"' : '' ?>>
                    <a class="page-link" href="<?= h($lienPage($n)) ?>"><?= $n ?></a>
                </li>
            <?php $precedent = $n; endforeach; ?>
            <li class="page-item <?= $page === $pages ? 'disabled' : '' ?>">
                <a class="page-link" href="<?= h($lienPage($page + 1)) ?>" aria-label="Page suivante">&raquo;</a>
            </li>
        </ul>
    </nav>
    <?php endif; ?>
</div>
