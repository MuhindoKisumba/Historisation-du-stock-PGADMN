--Hypothèses de base (tables minimales)
--=====================================
-- TABLE PRODUIT / ARTICLE
CREATE TABLE article (
    id_article SERIAL PRIMARY KEY,
    nom VARCHAR(100),
    prix NUMERIC(10,2) NOT NULL,
    stock INT NOT NULL CHECK (stock >= 0)
);

-- TABLE VENTE
CREATE TABLE vente (
    id_vente SERIAL PRIMARY KEY,
    id_article INT REFERENCES article(id_article),
    quantite INT NOT NULL CHECK (quantite > 0),
    prix_unitaire NUMERIC(10,2),
    montant_total NUMERIC(10,2),
    date_vente TIMESTAMP DEFAULT NOW()
);

--Trigger : calcul automatique du prix et du montant de la vente
--==============================================================
CREATE OR REPLACE FUNCTION fn_calcul_montant_vente()
RETURNS TRIGGER AS $$
BEGIN
    SELECT prix INTO NEW.prix_unitaire
    FROM article
    WHERE id_article = NEW.id_article;

    IF NEW.prix_unitaire IS NULL THEN
        RAISE EXCEPTION 'Article inexistant';
    END IF;

    NEW.montant_total := NEW.prix_unitaire * NEW.quantite;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--Trigger
--=======
CREATE TRIGGER trg_calcul_montant_vente
BEFORE INSERT ON vente
FOR EACH ROW
EXECUTE FUNCTION fn_calcul_montant_vente();


--Trigger : empêcher une vente avec prix modifié (fraude)
--=======================================================
CREATE OR REPLACE FUNCTION fn_verification_prix_vente()
RETURNS TRIGGER AS $$
DECLARE
    prix_article NUMERIC;
BEGIN
    SELECT prix INTO prix_article
    FROM article
    WHERE id_article = NEW.id_article;

    IF NEW.prix_unitaire <> prix_article THEN
        RAISE EXCEPTION 'Tentative de fraude : prix modifié';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--Trigger
=========
CREATE TRIGGER trg_verification_prix_vente
BEFORE INSERT OR UPDATE ON vente
FOR EACH ROW
EXECUTE FUNCTION fn_verification_prix_vente();

