local Timer = require "lib.knife.timer"
local push = require "lib.push"

-- Variables qu'on peut modifier pour changer le gameplay ou l'apparence du jeu
NOM = "xxxxxxxxx"
GRAVITE = 9.81 * 7
VENT = 0
JOUEUR_VITESSE = 8
JOUEUR_VITESSE_SAUT = 20
JOUEUR_TAILLE = 0.9
MONSTRES_VITESSE = JOUEUR_VITESSE * 0.5
MONSTRES_TAILLE = 0.8
VITESSE_CHUTE_MAX = 10
ECHELLE_DESSIN = 50
LARGEUR_JEU = 800
HAUTEUR_JEU = 600
TYPO = love.graphics.newFont("typos/retro.ttf", 64)
EPS = 1e-5
COLLISION_TYPE = {NONE = 0, GROUND = 1, WALL = 2}

-- Ne pas modifier ces variables
NIVEAU_ACTUEL = 0
NIVEAU = {}
JOUEURS = {}
MONSTRES = {}
ControleurFleches = {
    nom = "LR",
    id = "LR"
}
ControleurAD = {
    nom = "ZAD",
    id = "ZAD"
}
ControleurJoystick = {
    nom = "JOY" -- TODO ajouter le nom de la manette?
}
TOUCHES_PRESSEES = {}

-- Ne pas modifier ces variables, mais directement les fichiers
IMAGES = {
    joueur = love.graphics.newImage("images/joueur.png"),
    bloc = love.graphics.newImage("images/bloc.png"),
    monstre = love.graphics.newImage("images/monstre.png")
}
SONS = {
    defaite = love.audio.newSource("sons/defaite.mp3", "static"),
    mort = love.audio.newSource("sons/mort.mp3", "static"),
    saut = love.audio.newSource("sons/saut.mp3", "static"),
    victoire = love.audio.newSource("sons/victoire.mp3", "static"),
    musique_debut = love.audio.newSource("sons/musique-debut.mp3", "stream")
}

EtatActuel = nil
EtatDebut = {
    nom = "début"
}
EtatNiveauSuivant = {
    nom = "niveau_suivant"
}
EtatCombat = {
    nom = "combat",
    pause = false
}
EtatDefaite = { nom = "défaite" }
EtatVictoire = { nom = "victoire" }

function love.load()
    love.window.setTitle(NOM)
    love.graphics.setFont(TYPO)
    love.graphics.setDefaultFilter("nearest", "nearest")
    local largeurFenetre, hauteurFenetre = love.window.getDesktopDimensions()
    push:setupScreen(
        LARGEUR_JEU, HAUTEUR_JEU,
        largeurFenetre, hauteurFenetre,
        { fullscreen = false, resizable = true }
    )

    changerEtat(EtatDebut)
end

function love.update(dt)
    Timer.update(dt)
    if EtatActuel.update then
        EtatActuel:update(dt)
    end
    TOUCHES_PRESSEES = {}
end

function love.draw()
    push:start()
    if EtatActuel.dessiner then
        EtatActuel:dessiner()
    end
    push:finish()
end

function love.resize(largeur, hauteur)
    push:resize(largeur, hauteur)
end

function love.keypressed(touche)
    TOUCHES_PRESSEES[touche] = true
end

function changerEtat(nouvelEtat)
    if EtatActuel and EtatActuel.sortir then
        EtatActuel:sortir()
    end
    EtatActuel = nouvelEtat
    if EtatActuel.entrer then
        EtatActuel:entrer()
    end
end

function EtatDebut:entrer()
    SONS.musique_debut:play()
    SONS.musique_debut:setLooping(true)
end

function EtatDebut:update(dt)
    local nombreDeJoueurs = #JOUEURS

    -- Selection du joueur
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        local id = joystick:getID()
        if controleurDisponible(id) and joystick:isGamepadDown("a", "b", "start") then
            JOUEURS[#JOUEURS + 1] = {
                controleur = creerControleurJoystick(joystick)
            }
            joystick:setVibration(1, 1)
            Timer.after(0.1, function() joystick:setVibration(0, 0) end)
        end
    end
    if controleurDisponible(ControleurFleches.id) and (ControleurFleches:demarrer() or ControleurFleches:saut()) then
        JOUEURS[#JOUEURS + 1] = {
            controleur = ControleurFleches
        }
    end
    if controleurDisponible(ControleurAD.id) and ControleurAD:directionX() ~= 0 or ControleurAD:saut() then
        JOUEURS[#JOUEURS + 1] = {
            controleur = ControleurAD
        }
    end

    -- On regarde si aucun joueur n'a été ajouté (notamment en appuyant sur demarrer)
    if #JOUEURS > 0 and #JOUEURS == nombreDeJoueurs and joueursAppuientSurDemarrer() then
        -- On part au combat
        changerEtat(EtatNiveauSuivant)
    end
end

function controleurDisponible(id)
    -- retourne true si le controleur peut être assigné à un joueur
    if #JOUEURS == 4 then
        -- Seulement quatre joueurs supportés...
        return false
    end
    for _, joueur in ipairs(JOUEURS) do
        if joueur.controleur.id == id then
            return false
        end
    end
    return true
end

function EtatDebut:dessiner()
    love.graphics.setColor(1, 1, 0)
    ecrire(NOM, LARGEUR_JEU / 2, HAUTEUR_JEU * 0.3, 2)
    love.graphics.setColor(1, 1, 1)

    for j, joueur in ipairs(JOUEURS) do
        love.graphics.setColor(1, 1, 1)
        ecrire(
            string.format("player %d - %s", j, joueur.controleur.nom),
            LARGEUR_JEU / 2, HAUTEUR_JEU * (0.5 + j * 0.05),
            0.3
        )
    end
    for j = #JOUEURS + 1, 4 do
        love.graphics.setColor(0.5, 0.5, 0.5)
        ecrire(
            string.format("player %d", j),
            LARGEUR_JEU / 2, HAUTEUR_JEU * (0.5 + j * 0.05),
            0.3
        )
    end

    if #JOUEURS > 0 then
        ecrire("press start", LARGEUR_JEU / 2, HAUTEUR_JEU * 0.8, 0.5)
    else
        love.graphics.setColor(1, 1, 1)
        ecrire("en attente de joueurs...", LARGEUR_JEU / 2, HAUTEUR_JEU * 0.8, 0.3)
    end
end

function EtatDebut:sortir()
    SONS.musique_debut:stop()
    NIVEAU_ACTUEL = 0
end

function EtatNiveauSuivant:entrer()
    NIVEAU_ACTUEL = NIVEAU_ACTUEL + 1

    local fichierNiveau = string.format("niveaux/niveau-%03d.txt", NIVEAU_ACTUEL)
    local niveauInfo = love.filesystem.getInfo(fichierNiveau)
    if niveauInfo == nil then
        -- On a fait le dernier niveau !
        changerEtat(EtatVictoire)
    else
        -- On part au combat...
        chargerNiveau(fichierNiveau)
        Timer.after(2, function() changerEtat(EtatCombat) end)
    end
end

function EtatNiveauSuivant:dessiner()
    love.graphics.setColor(1, 1, 1)
    ecrire(
        string.format("Level %d", NIVEAU_ACTUEL),
        LARGEUR_JEU / 2,
        HAUTEUR_JEU * 0.4,
        1
    )
end

function chargerNiveau(path)
    NIVEAU = {}
    MONSTRES = {}
    NIVEAU.blocs = {}
    NIVEAU.tailleX = 0
    local y = 1
    for line in love.filesystem.lines(path) do
        NIVEAU.blocs[y] = {}
        for x = 1, #line do
            local caractere = line:sub(x, x)
            if caractere == "x" then
                NIVEAU.blocs[y][x] = 1
            elseif caractere == "m" then
                MONSTRES[#MONSTRES + 1] = {
                    x = x,
                    y = y,
                    vx = 0,
                    vy = 0,
                    vivant = true,
                    tailleX = MONSTRES_TAILLE,
                    tailleY = MONSTRES_TAILLE,
                    image = IMAGES.monstre,
                    collision_state = COLLISION_TYPE.NONE
                }
            else
                NIVEAU.blocs[y][x] = 0
            end
            NIVEAU.tailleX = math.max(NIVEAU.tailleX, x)
        end
        y = y + 1
    end

    -- Positionnement des joueurs
    for j, joueur in ipairs(JOUEURS) do
        local x = math.floor((NIVEAU.tailleX - 1) * j / (#JOUEURS + 1)) + 1
        local y = #NIVEAU.blocs - 2
        while NIVEAU.blocs[y][x] == 1 do
            y = (y - 1) % #NIVEAU.blocs
        end
        joueur.x = x
        joueur.y = y
        joueur.vx = 0
        joueur.vy = 0
        joueur.vivant = true
        joueur.tailleX = JOUEUR_TAILLE
        joueur.tailleY = JOUEUR_TAILLE
        joueur.image = IMAGES.joueur
    end
end

function EtatCombat:entrer()
    EtatCombat.pause = false
end

function EtatCombat:update(dt)
    -- Appuyer sur pause
    if joueursAppuientSurDemarrer() then
        EtatCombat.pause = not EtatCombat.pause
    end
    if EtatCombat.pause then
        return
    end

    -- Calcul des vitesses
    for _, joueur in ipairs(JOUEURS) do
        if joueur.vivant then
            calculerVitesseJoueur(joueur, dt)

            joueur.collision_state, residual_dt, vitesse_slide_final = bouge_et_collisionne(joueur, dt)
            joueur.vx = vitesse_slide_final.x
            joueur.vy = vitesse_slide_final.y

            collision2 = bouge_et_collisionne(joueur, residual_dt)
        end
    end
    for _, monstre in ipairs(MONSTRES) do
        if monstre.vivant then
            calculerVitesseMonstre(monstre, dt)

            original_vx = monstre.vx
            monstre.collision_state, residual_dt, vitesse_slide_final = bouge_et_collisionne(monstre, dt)
            monstre.vx = vitesse_slide_final.x
            monstre.vy = vitesse_slide_final.y

            collision2 = bouge_et_collisionne(monstre, residual_dt)

            if monstre.collision_state == COLLISION_TYPE.WALL or collision2 == COLLISION_TYPE.WALL then
                monstre.vx = -original_vx
            end
        end
    end

    -- Collision entre les joueurs et les monstres
    for _, joueur in ipairs(JOUEURS) do
        if joueur.vivant then
            for _, monstre in ipairs(MONSTRES) do
                if monstre.vivant then
                    -- si le joueur va rentrer en collision avec le monstre et que les pieds
                    -- du joueur étaient au dessus de la tête du monstre, alors on a tué le monstre
                    if joueur.vy > 0 and testCollision(
                            joueur.x + joueur.vx * dt, joueur.y + joueur.vy * dt,
                            joueur.tailleX, joueur.tailleY,
                            monstre.x, monstre.y,
                            monstre.tailleX, monstre.tailleY
                        ) and joueur.y + joueur.tailleY / 2 < monstre.y - monstre.tailleY / 2 then
                        -- Monstre écrasé !
                        Timer.after(1 / 12, function()
                            monstre.tailleY = monstre.tailleY / 2
                            monstre.y = monstre.y + monstre.tailleY * 3 / 4
                        end)
                        Timer.after(2 / 12, function() monstre.tailleY = 0 end)
                        monstre.vivant = false
                        -- Est-ce que c'était le dernier monstre vivant ?
                        if niveauGagne() then
                            SONS.victoire:play()
                            Timer.after(2, function() changerEtat(EtatNiveauSuivant) end)
                        end
                    elseif testCollision(
                            joueur.x, joueur.y,
                            joueur.tailleX, joueur.tailleY,
                            monstre.x, monstre.y,
                            monstre.tailleX, monstre.tailleY
                        ) then
                        -- Joueur mort !
                        joueur.vivant = false
                        Timer.tween(1, {
                            -- on rend le joueur tout petit
                            [joueur] = { tailleX = 0, tailleY = 0 }
                        })
                        SONS.mort:play()
                        -- Est-ce que c'était le dernier joueur vivant ?
                        if niveauPerdu() then
                            Timer.after(2, function() changerEtat(EtatDefaite) end)
                        end
                    end
                end
            end
        end
    end

    -- Déplacements
    for _, joueur in ipairs(JOUEURS) do
        if joueur.vivant then
            deplacerObjet(joueur, dt)
        end
    end
    for _, monstre in ipairs(MONSTRES) do
        if monstre.vivant then
            deplacerObjet(monstre, dt)
        end
    end
end

function niveauGagne()
    -- Le niveau est gagné si tous les monstres sont morts.
    for _, monstre in ipairs(MONSTRES) do
        if monstre.vivant then
            return false
        end
    end
    return true
end

function niveauPerdu()
    -- Le niveau est perdu s'il n'y a plus un seul joueur vivant.
    for _, joueur in ipairs(JOUEURS) do
        if joueur.vivant then
            return false
        end
    end
    return true
end

function calculerVitesseMonstre(monstre, dt)
    if monstre.vx == 0 and monstre.collision_state == COLLISION_TYPE.GROUND then
        -- quand le monstre est sur le sol avec une vitesse horizontale nulle, on le
        -- fait se déplacer dans une direction au hasard
        monstre.vy = 0
        monstre.vx = (math.random(0, 1) * 2 - 1) * MONSTRES_VITESSE
    end
    local directionInitiale = signe(monstre.vx)

    calculerVitesse(monstre, dt)

    if directionInitiale ~= 0 and monstre.vx == 0 then
        -- le monstre a fait une collision, on change de direction
        monstre.vx = -directionInitiale * MONSTRES_VITESSE
    end
end

function calculerVitesseJoueur(joueur, dt)
    -- Déplacement à gauche et à droite
    joueur.vx = joueur.controleur:directionX() * JOUEUR_VITESSE

    -- saut
    if joueur.controleur:saut() and joueur.collision_state == COLLISION_TYPE.GROUND then
        -- TODO comment sauter plus haut en fonction de la durée pendant laquelle on appuie?
        joueur.vy = -JOUEUR_VITESSE_SAUT
        SONS.saut:play()
    end

    calculerVitesse(joueur, dt)
end

function calculerVitesse(objet, dt)
    -- On applique la gravité
    objet.vy = objet.vy + GRAVITE * dt

    -- Vitesse de chute à ne pas dépasser
    if objet.vy > VITESSE_CHUTE_MAX then
        objet.vy = VITESSE_CHUTE_MAX
    end
end

function intersect_range(a_min, a_max, b_min, b_max)
    r_min = math.max(a_min, b_min)
    r_max = math.min(a_max, b_max)

    return (r_min <= r_max)
end


function calcul_moving_boundaries(objet, dt)
    xmin_objet = objet.x - objet.tailleX / 2
    ymin_objet = objet.y - objet.tailleY / 2

    xmax_objet = objet.x + objet.tailleX / 2
    ymax_objet = objet.y + objet.tailleY / 2

    if (objet.vx < 0) then
        xmin_objet = xmin_objet + objet.vx * dt
    else
        xmax_objet = xmax_objet + objet.vx * dt
    end

    if (objet.vy < 0) then
        ymin_objet = ymin_objet + objet.vy * dt
    else
        ymax_objet = ymax_objet + objet.vy * dt
    end

    return xmin_objet, xmax_objet, ymin_objet, ymax_objet
end

function calcul_static_boundaries(x, y, sx, sy)
    return x - sx/2, x + sx / 2, y - sy / 2, y + sy / 2
end

function test_collision(objet, dt, x, y, sx, sy)
    xmin_objet, xmax_objet, ymin_objet, ymax_objet = calcul_moving_boundaries(objet, dt)
    xmin_avant, xmax_avant, ymin_avant, ymax_avant = calcul_static_boundaries(objet.x, objet.y, objet.tailleX, objet.tailleY)
    xmin_apres, xmax_apres, ymin_apres, ymax_apres = calcul_static_boundaries(objet.x + objet.vx * dt, objet.y + objet.vy * dt, objet.tailleX, objet.tailleY)
    xmin_bloc, xmax_bloc, ymin_bloc, ymax_bloc = calcul_static_boundaries(x, y, sx, sy)

    ratio = 1
    vitesse_slide = {x = objet.vx, y = objet.vy}
    collision_type = COLLISION_TYPE.NONE

    -- détection collision gauche-droite
    if objet.vx > 0 and
        (xmax_apres > xmin_bloc) and
        (xmax_avant < xmin_bloc) and
        intersect_range(ymin_objet, ymax_objet, ymin_bloc, ymax_bloc) then
            ratio = (xmin_bloc - xmax_avant) / (xmax_apres - xmax_avant) - EPS
            vitesse_slide.x = 0
            collision_type = COLLISION_TYPE.WALL

    -- détection collision droite-gauche
    elseif objet.vx < 0 and
        (xmin_apres < xmax_bloc) and
        (xmin_avant > xmax_bloc) and
        intersect_range(ymin_objet, ymax_objet, ymin_bloc, ymax_bloc) then
            ratio = (xmax_bloc - xmin_avant) / (xmin_apres - xmin_avant) - EPS
            vitesse_slide.x = 0
            collision_type = COLLISION_TYPE.WALL

    -- détection collision bas-haut
    elseif objet.vy > 0 and
        (ymax_apres > ymin_bloc) and
        (ymax_avant < ymin_bloc) and
        intersect_range(xmin_objet, xmax_objet, xmin_bloc, xmax_bloc) then
            ratio = (ymin_bloc - ymax_avant) / (ymax_apres - ymax_avant) - EPS
            vitesse_slide.y = 0
            collision_type = COLLISION_TYPE.GROUND

    -- détection collision haut-bas
    elseif objet.vy < 0 and
        (ymin_apres > ymax_bloc) and
        (ymin_avant < ymax_bloc) and
        intersect_range(xmin_objet, xmax_objet, xmin_bloc, xmax_bloc) then
            ratio = (ymax_bloc - ymin_avant) / (ymin_apres - ymin_avant) - EPS
            vitesse_slide.y = 0
            collision_type = COLLISION_TYPE.NONE
    end

    ratio = math.max(0, ratio)  -- avoid negative ratio

    return ratio, vitesse_slide, collision_type

end

function bouge_et_collisionne(objet, dt)
    xmin_objet, xmax_objet, ymin_objet, ymax_objet = calcul_moving_boundaries(objet, dt)

    index_xmin = math.floor(xmin_objet)
    index_xmax = math.ceil(xmax_objet)
    index_ymin = math.floor(ymin_objet)
    index_ymax = math.ceil(ymax_objet)

    ratio_final = 1
    vitesse_slide_final = {x = objet.vx, y = objet.vy}
    local collision_type = COLLISION_TYPE.NONE

    -- collisions avec les blocs
    for y = index_ymin, index_ymax do
        if y < 1 or y > #NIVEAU.blocs then
        else
            for x = index_xmin, index_xmax do
                if x < 1 or x > #NIVEAU.blocs[y] then
                else
                    if NIVEAU.blocs[y][x] == 1 then
                        ratio, vitesse_slide, tmp_collision = test_collision(objet, dt, x, y, 1, 1)
                        if ratio < ratio_final then
                            ratio_final = ratio
                            vitesse_slide_final = vitesse_slide
                            collision_type = tmp_collision
                        end
                    end
                end
            end
        end
    end

    objet.x = objet.x + ratio_final * dt * objet.vx
    objet.y = objet.y + ratio_final * dt * objet.vy

    residual_dt = dt * (1 - ratio_final)

    return collision_type, residual_dt, vitesse_slide_final
end

function deplacerObjet(objet, dt)
    -- déplacement
    next_pos_x = objet.x + objet.vx * dt
    next_pos_y = objet.y + objet.vy * dt

    -- on garde l'objet dans les bornes du terrain
    objet.x = math.min(NIVEAU.tailleX, math.max(1, objet.x))

    -- quand l'objet tombe, on le fait remonter
    while objet.y > #NIVEAU.blocs do
        objet.y = objet.y - #NIVEAU.blocs
    end
end

function testCollision(x1, y1, sx1, sy1, x2, y2, sx2, sy2)
    -- retourne "true" si les deux rectangles se superposent
    if x1 + sx1 / 2 <= x2 - sx2 / 2 or x2 + sx2 / 2 <= x1 - sx1 / 2 then
        return false
    end
    if y1 + sy1 / 2 <= y2 - sy2 / 2 or y2 + sy2 / 2 <= y1 - sy1 / 2 then
        return false
    end
    return true
end

function testObjetSurLeSol(objet)
    -- est-ce que l'objet est sur le sol?
    local solY = objet.y + objet.tailleY / 2 + 1 / 2
    if solY < 1 or solY > #NIVEAU.blocs or solY ~= math.floor(solY) then
        return false
    end
    local minX = math.max(1, math.ceil(objet.x - objet.tailleX / 2 - 1 / 2))
    local maxX = math.min(#NIVEAU.blocs[solY], math.floor(objet.x + objet.tailleX / 2 + 1 / 2))
    for solX = minX, maxX do
        if math.abs(solX - objet.x) < objet.tailleX / 2 + 1 / 2 then
            if NIVEAU.blocs[solY][solX] == 1 then
                return true
            end
        end
    end
    return false
end

function EtatCombat:dessiner()
    dessinerNiveau()
    for _, monstre in ipairs(MONSTRES) do
        dessinerObjet(monstre)
    end
    for _, joueur in ipairs(JOUEURS) do
        dessinerObjet(joueur)
    end

    if EtatCombat.pause then
        ecrire("pause", LARGEUR_JEU / 2, HAUTEUR_JEU / 2, 1)
    end
end

function dessinerNiveau()
    for y = 1, #NIVEAU.blocs do
        for x = 1, #NIVEAU.blocs[y] do
            if NIVEAU.blocs[y][x] == 1 then
                dessinerImage(x, y, 1, 1, IMAGES.bloc)
            end
        end
    end
end

function dessinerObjet(objet)
    dessinerImage(objet.x, objet.y, objet.tailleX, objet.tailleY, objet.image)
end

function dessinerImage(x, y, tailleX, tailleY, image)
    local echelle = math.min(LARGEUR_JEU / NIVEAU.tailleX, HAUTEUR_JEU / #NIVEAU.blocs)
    local offsetX = (LARGEUR_JEU - NIVEAU.tailleX * echelle) / 2
    local offsetY = (HAUTEUR_JEU - #NIVEAU.blocs * echelle) / 2
    love.graphics.draw(
        image,
        (x - 1 - tailleX / 2) * echelle + offsetX,
        (y - 1 - tailleY / 2) * echelle + offsetY,
        0,                                      -- orientation
        (tailleX / image:getWidth()) * echelle, -- scaleX
        (tailleY / image:getHeight()) * echelle -- scaleY
    )
end

function signe(nombre)
    if nombre < 0 then
        return -1
    elseif nombre > 0 then
        return 1
    else
        return 0
    end
end

function EtatDefaite:entrer(dt)
    SONS.defaite:play()
end

function EtatDefaite:update(dt)
    if joueursAppuientSurDemarrer() then
        changerEtat(EtatDebut)
    end
end

function EtatDefaite:dessiner()
    love.graphics.setColor(1, 1, 1)
    ecrire("Game\nOver", LARGEUR_JEU / 2, HAUTEUR_JEU * 0.3, 2)
    ecrire("press start", LARGEUR_JEU / 2, HAUTEUR_JEU * 0.8, 0.5)
end

function EtatVictoire:update(dt)
    if joueursAppuientSurDemarrer() then
        changerEtat(EtatDebut)
    end
end

function EtatVictoire:dessiner()
    love.graphics.setColor(1, 1, 1)
    ecrire("gg!", LARGEUR_JEU / 2, HAUTEUR_JEU / 2, 5)
end

function ecrire(texte, x, y, echelle)
    local largeur = TYPO:getWidth(texte) * echelle
    local hauteur = TYPO:getHeight() * echelle
    love.graphics.print(
        texte,
        x - largeur / 2,
        y - hauteur / 2,
        0,
        echelle, echelle
    )
end

function joueursAppuientSurDemarrer()
    for _, joueur in ipairs(JOUEURS) do
        if joueur.controleur:demarrer() then
            return true
        end
    end
    return false
end

function ControleurFleches:directionX()
    local dirX = 0
    if love.keyboard.isDown("left") then
        dirX = dirX - 1
    end
    if love.keyboard.isDown("right") then
        dirX = dirX + 1
    end
    return dirX
end

function ControleurFleches:saut()
    return TOUCHES_PRESSEES["rctrl"]
end

function ControleurFleches:demarrer()
    return TOUCHES_PRESSEES["return"]
end

function ControleurAD:directionX()
    local dirX = 0
    if love.keyboard.isDown("q") or love.keyboard.isDown("a") then
        dirX = dirX - 1
    end
    if love.keyboard.isDown("d") then
        dirX = dirX + 1
    end
    return dirX
end

function ControleurAD:saut()
    return TOUCHES_PRESSEES["lshift"]
end

function ControleurAD:demarrer()
    -- note: même touche que le contrôleur avec des flèches
    return TOUCHES_PRESSEES["space"]
end

function ControleurJoystick.directionX(controleur)
    local dirX = controleur.joystick:getGamepadAxis("leftx")
    if math.abs(dirX) < 0.2 then
        -- on limite les petits déplacements
        dirX = 0
    end
    return dirX
end

function ControleurJoystick.saut(controleur)
    return controleur.joystick:isGamepadDown("a", "b")
end

function ControleurJoystick.demarrer(controleur)
    return controleur.joystick:isGamepadDown("start")
end

function creerControleurJoystick(joystick)
    local controleur = {}
    for k, v in pairs(ControleurJoystick) do
        controleur[k] = v
    end
    controleur.joystick = joystick
    controleur.id = joystick:getID()
    return controleur
end
