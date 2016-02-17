# VectorBase RNAseq tracks database tables definitions

/**

SRA tracking tables

*/

/**

@study table
@desc The study tables contains data defining SRA studies

@study_id           SRA study id. Primary key, internal identifier.
@study_sra_acc      SRA study accession.
@title              Title of the SRA study.
@abstract           Abstract of the SRA study.
@metasum            Checksum of @title + @abstract.
@date               Entry creation timestamp.
@status             Active (True) or retired (False) row.

*/

CREATE TABLE study (
  study_id          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  study_sra_acc     CHAR(9) NOT NULL,
  title             TEXT,
  abstract          TEXT,
  metasum           CHAR(32),
  date              DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status            BOOLEAN DEFAULT True,
  
  KEY study_id_idx  (study_id),
  KEY study_sra_acc_idx  (study_sra_acc),
  UNIQUE KEY (study_id, study_sra_acc)
) ENGINE=MyISAM;

