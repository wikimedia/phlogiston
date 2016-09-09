CREATE OR REPLACE FUNCTION convert_blocked_phid_to_id_sql(
) RETURNS void AS $$

  INSERT INTO maniphest_blocked
  SELECT mb.blocked_date, mt1.id, mt2.id
    FROM maniphest_blocked_phid mb,
         maniphest_task mt1,
         maniphest_task mt2
   WHERE mb.blocks_phid = mt1.phid
     AND mb.blocked_by_phid = mt2.phid

$$ LANGUAGE SQL VOLATILE;
