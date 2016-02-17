# VectorBase RNAseq tracks database tables definitions

/**

SRA tracking tables

*/

/**

@study table
@desc The study tables contains data defining SRA studies.

@study_id           SRA study id. Primary key, internal identifier.
@study_sra_acc      SRA study accession.
@title              Title of the SRA study.
@abstract           Abstract of the SRA study.
@metasum            Checksum of @title + @abstract.
@date               Entry timestamp.
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

/**

@experiment table
@desc The experiment tables contains data defining SRA experiments.

@experiment_id           SRA experiment id. Primary key, internal identifier.
@experiment_sra_acc      SRA experiment accession.
@title                   Title of the SRA experiment.
@description             Description of the SRA experiment.
@study_id                Study table study_id (Foreign key).
@metasum                 Checksum of @title + @description.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE experiment (
  experiment_id          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  experiment_sra_acc     CHAR(9) NOT NULL,
  title                  TEXT,
  description            TEXT,
  metasum                CHAR(32),
  date                   DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                 BOOLEAN DEFAULT True,
  
  KEY experiment_id_idx  (experiment_id),
  KEY experiment_sra_acc_idx  (experiment_sra_acc),
  UNIQUE KEY (experiment_id, experiment_sra_acc)
) ENGINE=MyISAM;

/**

@run table
@desc The run tables contains data defining SRA runs.

@run_id                  SRA run id. Primary key, internal identifier.
@run_sra_acc             SRA run accession.
@title                   Title of the SRA run.
@submitter               Submitter id of the SRA run.
@experiment_id           Experiment table experiment_id (Foreign key).
@metasum                 Checksum of @title.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE run (
  run_id                 INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  run_sra_acc            CHAR(9) NOT NULL,
  title                  TEXT,
  submitter              TEXT,
  metasum                CHAR(32),
  date                   DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                 BOOLEAN DEFAULT True,
  
  KEY run_id_idx        (run_id),
  KEY run_sra_acc_idx   (run_sra_acc),
  UNIQUE KEY            (run_id, run_sra_acc)
) ENGINE=MyISAM;


/**

PIPELINE TABLES

*/

/**

@file table
@desc The table where all metadata about the tracks files are stored.

@file_id                File id. Primary key, internal identifier.
@run_id                 Run table experiment_id (Foreign key).
@path                   Path of the file.
@type                   File type.
@taxon_id               NCBI taxon id of the species.
@species                Binomial name of the species.
@md5                    md5 checksum of the file.
@metasum                Checksum of @species + @md5.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE file (
  file_id               INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  run_id                INT(10),
  path                  TEXT,
  type                  ENUM('fastq', 'bam', 'bed', 'bigwig'),
  taxon_id              INT(10),
  species               TEXT,
  md5                   CHAR(32),
  metasum               CHAR(32),
  date                  DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                BOOLEAN DEFAULT True,
  
  KEY file_id_idx        (file_id),
  UNIQUE KEY            (file_id)
) ENGINE=MyISAM;


/**

@analysis table
@desc The table the analysis are stored.

@analysis_id            Analysis id. Primary key, internal identifier.
@name                   Name of the analysis.
@description            Description of the analysis.
@metasum                Checksum of @name + @description.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE analysis (
  analysis_id           INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  name                  TEXT,
  description           TEXT,
  metasum               CHAR(32),
  date                  DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                BOOLEAN DEFAULT True,
  
  KEY file_id_idx        (analysis_id),
  UNIQUE KEY            (analysis_id)
) ENGINE=MyISAM;

