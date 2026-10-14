<?php
// Fermeture du formulaire ouvert par form_debut.php.
// Variables : $modale, $retour (page d'annulation), $libelleBouton, $classeBouton.
$libelleBouton = $libelleBouton ?? 'Enregistrer';
$classeBouton = $classeBouton ?? 'btn-primary';
?>
<?php if ($modale): ?>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button>
                <button class="btn <?= h($classeBouton) ?>"><?= h($libelleBouton) ?></button>
            </div>
        </form>
    </div>
</div>
<?php else: ?>
            <div class="mt-4 d-flex gap-2">
                <button class="btn <?= h($classeBouton) ?>"><?= h($libelleBouton) ?></button>
                <a href="<?= h($retour) ?>" class="btn btn-outline-secondary">Annuler</a>
            </div>
        </form>
    </div>
</div>
<?php endif; ?>
