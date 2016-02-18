-- VectorBase RNAseq tracks database tables definitions


/**
@header Vectorbase RNAseq tracks Tables
@colour  #000

*/


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
@study_id                Study table primary id (foreign key).
@experiment_sra_acc      SRA experiment accession.
@title                   Title of the SRA experiment.
@metasum                 Checksum of @title + @description.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE experiment (
  experiment_id          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  experiment_sra_acc     CHAR(9) NOT NULL,
  title                  TEXT,
  metasum                CHAR(32),
  date                   DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                 BOOLEAN DEFAULT True,
  
  KEY experiment_id_idx       (experiment_id),
  KEY experiment_sra_acc_idx  (experiment_sra_acc),
  UNIQUE KEY                  (experiment_id, experiment_sra_acc)
) ENGINE=MyISAM;

/**

@run table
@desc The run tables contains data defining SRA runs.

@run_id                  SRA run id. Primary key, internal identifier.
@experiment_id           Experiment table primary key (Foreign key).
@run_sra_acc             SRA run accession.
@title                   Title of the SRA run.
@submitter               Submitter id of the SRA run.
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
@run_id                 Run table primary id (foreign key).
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
  
  KEY file_id_idx       (file_id),
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
  
  KEY analysis_id_idx      (analysis_id),
  UNIQUE KEY               (analysis_id)
) ENGINE=MyISAM;


/**

@analysis_param table
@desc The table where the analysis parameters are stored.

@analysis_param_id      Analysis parameters id. Primary key, internal identifier.
@analysis_id            Analysis table primary id (foreigh key).
@in_file                Input file, file table id (foreign key).
@out_file               Output file, file table id (foreign key).
@program                Name of the Program used.
@parameters             Command line parameters used.
@metasum                Checksum of @in_file + @out_file + @program + @parameters.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE analysis_param (
  analysis_param_id     INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  analysis_id           INT(10),
  in_file               TEXT,
  out_file              TEXT,
  program               TEXT,
  parameters            TEXT,
  metasum               CHAR(32),
  date                  DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                BOOLEAN DEFAULT True,
  
  KEY analysis_param_id_idx   (analysis_param_id),
  UNIQUE KEY                  (analysis_param_id)
) ENGINE=MyISAM;


/**

@track table
@desc The table where the tracks are stored.

@track_id               Track id. Primary key, internal identifier.
@analysis_param_id      Analysis_param table primary id (foreigh key).
@title                  Title of the track in E! genome browser.
@description            Description of the track in E! genome browser.
@metasum                Checksum of @title + @description.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE track (
  track_id              INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  analysis_param_id     INT(10),
  title                 TEXT,
  description           TEXT,
  metasum               CHAR(32),
  date                  DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                BOOLEAN DEFAULT True,
  
  KEY track_id_idx      (track_id),
  UNIQUE KEY            (track_id)
) ENGINE=MyISAM;


/**

PUBLICATIONS TABLES

*/

/**

@publication table
@desc The table where the publication infos are stored.

@publication_id         Publication id. Primary key, internal identifier.
@pubmed_id              Pubmed id.
@doi                    Digital object identifier.
@authors                List of authors.
@title                  Title of the publication.
@abstract               Abstract of the publication.
@year                   Year of publication.
@metasum                Checksum of @title + @abstract.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE publication (
  publication_id        INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  pubmed_id             INT(10),
  doi                   VARCHAR(32),
  authors               TEXT,
  title                 TEXT,
  abstract              TEXT,
  year                  INT(4),
  metasum               CHAR(32),
  date                  DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                BOOLEAN DEFAULT True,
  
  KEY publication_id_idx        (publication_id),
  KEY pubmed_id_idx             (pubmed_id),
  UNIQUE KEY                    (publication_id)
) ENGINE=MyISAM;


/**

@experiment_publication table
@desc Link table between experiments and publications.

@exp_lnk_pub_id         Experiment-Publication link id. Primary key, internal identifier.
@experiment_id          Experiment table primary id (foreign key).
@publication_id         Publication table primary id (foreign key).
@metasum                Checksum of @pub_id + @experiment_id.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE experiment_publication (
  exp_pub_link_id       INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  experiment_id         INT(10),
  publication_id        INT(10),
  metasum               CHAR(32),
  date                  DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  status                BOOLEAN DEFAULT True,
  
  KEY exp_pub_link_id_idx   (exp_pub_link_id),
  UNIQUE KEY                (exp_pub_link_id)
) ENGINE=MyISAM;

