<?php $titre = $edition ? "Modifier l'utilisateur" : 'Nouvel utilisateur'; ?>
<div class="card shadow-sm border-0" style="max-width: 720px;">
    <div class="card-header bg-brand text-white"><h5 class="mb-0"><?= h($titre) ?></h5></div>
    <div class="card-body">
        <form method="post" autocomplete="off">
            <?= csrf_field() ?>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label" for="NomUtilisateur">Nom d'utilisateur (connexion)</label>
                    <input class="form-control" id="NomUtilisateur" name="NomUtilisateur" value="<?= h($u['NomUtilisateur'] ?? '') ?>" required>
                </div>
                <div class="col-md-6">
                    <label class="form-label" for="NomComplet">Nom complet</label>
                    <input class="form-control" id="NomComplet" name="NomComplet" value="<?= h($u['NomComplet'] ?? '') ?>" required>
                </div>
                <div class="col-md-6">
                    <label class="form-label" for="MotPasse">Mot de passe</label>
                    <input class="form-control" type="password" id="MotPasse" name="MotPasse" autocomplete="new-password" <?= $edition ? '' : 'required' ?>>
                    <?php if ($edition): ?><div class="form-text">Laisser vide pour ne pas le changer.</div><?php endif; ?>
                </div>
                <div class="col-md-6">
                    <label class="form-label" for="Profil">Profil</label>
                    <select class="form-select" id="Profil" name="Profil">
                        <?php foreach ($profils as $p): ?><option <?= ($u['Profil'] ?? '') === $p ? 'selected' : '' ?>><?= $p ?></option><?php endforeach; ?>
                    </select>
                </div>
                <?php if (is_super_admin()): ?>
                    <div class="col-md-6">
                        <label class="form-label" for="TenantId">Société</label>
                        <select class="form-select" id="TenantId" name="TenantId">
                            <option value="">-- Aucune (SuperAdmin) --</option>
                            <?php foreach ($societes as $s): ?>
                                <option value="<?= (int) $s['Id'] ?>" <?= (int) ($u['TenantId'] ?? 0) === (int) $s['Id'] ? 'selected' : '' ?>><?= h($s['Nom']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                <?php endif; ?>
                <div class="col-12">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="1" id="PeutValiderOperations" name="PeutValiderOperations" <?= !empty($u['PeutValiderOperations']) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="PeutValiderOperations">Peut valider / rejeter les opérations de caisse</label>
                    </div>
                </div>
            </div>
            <div class="mt-4 d-flex gap-2">
                <button class="btn btn-primary">Enregistrer</button>
                <a href="<?= h(url('utilisateur/index')) ?>" class="btn btn-outline-secondary">Annuler</a>
            </div>
        </form>
    </div>
</div>
