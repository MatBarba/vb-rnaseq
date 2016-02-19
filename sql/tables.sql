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

@study_id           SRA study id (primary key, internal identifier).
@study_sra_acc      SRA study accession (e.g. SRP000000).
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
  date              TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status            ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY study_id_idx        (study_id),
  KEY study_sra_acc_idx   (study_sra_acc),
  UNIQUE KEY              (study_id, study_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER study_md5_upd_tr BEFORE UPDATE ON study
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.abstract) );
CREATE TRIGGER study_md5_ins_tr BEFORE INSERT ON study
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.abstract) );

/**

@experiment table
@desc The experiment tables contains data defining SRA experiments.

@experiment_id           SRA experiment id (primary key, internal identifier).
@study_id                Study table primary id (foreign key).
@experiment_sra_acc      SRA experiment accession (e.g. SRX000000).
@title                   Title of the SRA experiment.
@metasum                 Checksum of @title.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE experiment (
  experiment_id          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  study_id               INT(10),
  experiment_sra_acc     CHAR(9) NOT NULL,
  title                  TEXT,
  metasum                CHAR(32),
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY experiment_id_idx            (experiment_id),
  KEY experiment_study_id_idx      (study_id),
  KEY experiment_sra_acc_idx       (experiment_sra_acc),
  UNIQUE KEY                       (experiment_id, study_id, experiment_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER experiment_md5_upd_tr BEFORE UPDATE ON experiment
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title) );
CREATE TRIGGER experiment_md5_ins_tr BEFORE INSERT ON experiment
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title) );

/**

@run table
@desc The run tables contains data defining SRA runs.

@run_id                  SRA run id (primary key, internal identifier).
@experiment_id           Experiment table primary key (Foreign key).
@run_sra_acc             SRA run accession (e.g. SRR000000).
@title                   Title of the SRA run.
@submitter               Submitter id of the SRA run.
@metasum                 Checksum of @title.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE run (
  run_id                 INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  experiment_id          INT(10),
  run_sra_acc            CHAR(9) NOT NULL,
  title                  TEXT,
  submitter              TEXT,
  metasum                CHAR(32),
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY run_id_idx              (run_id),
  KEY run_experiment_id_idx   (experiment_id),
  KEY run_sra_acc_idx         (run_sra_acc),
  UNIQUE KEY                  (run_id, experiment_id, run_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER run_md5_upd_tr BEFORE UPDATE ON run
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title) );
CREATE TRIGGER run_md5_ins_tr BEFORE INSERT ON run
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title) );

/**

@sample table
@desc The sample tables contains data defining SRA samples.

@sample_id               SRA sample id (primary key, internal identifier).
@sample_sra_acc          SRA sample accession (e.g. SRS000000).
@run_id                  Run table primary key (Foreign key).
@title                   Title of the SRA sample.
@taxon                   NCBI taxon id.
@strain                  Name of the strain.
@metasum                 Checksum of @title.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE sample (
  sample_id                 INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  sample_sra_acc            CHAR(9) NOT NULL,
  run_id                    INT(10),
  title                     TEXT,
  taxon_id                  INT(10),
  strain                    TEXT,
  metasum                   CHAR(32),
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY sample_id_idx              (sample_id),
  KEY sample_experiment_id_idx   (experiment_id),
  KEY sample_sra_acc_idx         (sample_sra_acc),
  UNIQUE KEY                  (sample_id, experiment_id, sample_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER sample_md5_upd_tr BEFORE UPDATE ON sample
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title) );
CREATE TRIGGER sample_md5_ins_tr BEFORE INSERT ON sample
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title) );

/**

@species table
@desc A list of all existing (allowed) species, with the corresponding production names.

@species_id              Species id (primary key, internal identifier).
@species_name            Production name for this species (species + strain).
@taxon_id                NCBI species id.
@strain                  Name of the strain.
@metasum                 Checksum of @species_name + @taxon + @strain.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE species (
  species_id                INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  species_name              TEXT,
  taxon_id                  INT(10),
  strain                    TEXT,
  metasum                   CHAR(32),
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY species_id_idx              (species_id),
  UNIQUE KEY                      (species_id)
) ENGINE=MyISAM;

CREATE TRIGGER species_md5_upd_tr BEFORE UPDATE ON species
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.species_name, NEW.taxon_id, NEW.strain) );
CREATE TRIGGER species_md5_ins_tr BEFORE INSERT ON species
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.species_name, NEW.taxon_id, NEW.strain) );


/**

PIPELINE TABLES

*/

/**

@file table
@desc The table where all metadata about the files are stored. The files are both the input (e.g. fastq) and the output (e.g. bigwig) of the program (analysis) used to create tracks.

@file_id                File id (primary key, internal identifier).
@run_id                 Run table primary id (foreign key).
@path                   Path of the file.
@type                   File type.
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
  md5                   CHAR(32),
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY file_id_idx            (file_id),
  KEY file_run_id_idx        (run_id),
  UNIQUE KEY                 (file_id, run_id)
) ENGINE=MyISAM;

CREATE TRIGGER file_md5_upd_tr BEFORE UPDATE ON file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.species, NEW.md5) );
CREATE TRIGGER file_md5_ins_tr BEFORE INSERT ON file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.species, NEW.md5) );

/**

@analysis table
@desc The table where all the analysis to create tracks are described.

@analysis_id            Analysis id (primary key, internal identifier).
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
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY analysis_id_idx      (analysis_id),
  UNIQUE KEY               (analysis_id)
) ENGINE=MyISAM;

CREATE TRIGGER analysis_md5_upd_tr BEFORE UPDATE ON analysis
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.name, NEW.description) );
CREATE TRIGGER analysis_md5_ins_tr BEFORE INSERT ON analysis
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.name, NEW.description) );

/**

@analysis_param table
@desc The table where the analysis parameters used to create each track are stored.

@analysis_param_id      Analysis parameters id (primary key, internal identifier).
@analysis_id            Analysis table primary id (foreigh key).
@program                Name of the Program used.
@parameters             Complete command line parameters used.
@metasum                Checksum of @in_file + @out_file + @program + @parameters.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE analysis_param (
  analysis_param_id     INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  analysis_id           INT(10),
  program               TEXT,
  parameters            TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY analysis_param_id_idx            (analysis_param_id),
  KEY analysis_param_analysis_id_idx   (analysis_id),
  UNIQUE KEY                           (analysis_param_id, analysis_id)
) ENGINE=MyISAM;

CREATE TRIGGER analysis_param_md5_upd_tr BEFORE UPDATE ON analysis_param
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.parameters) );
CREATE TRIGGER analysis_param_md5_ins_tr BEFORE INSERT ON analysis_param
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.parameters) );

/**

@file_anap_link table
@desc Linker between file_id and analysis_parameter_id.

@file_anap_link_id            Analysis parameters id (primary key, internal identifier).
@file_id                      File table primary id (foreign key).
@analysis_parameter_id        Analysis_parameter table primary id (foreigh key).
@file_type                    If the file is an input or an output.
@metasum                      Checksum of @file_id + @analysis_parameter_id.

*/

CREATE TABLE file_anap_link (
  file_anap_link_id           INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  file_id                     INT(10),
  analysis_parameter_id       INT(10),
  file_type                   ENUM('INPUT', 'OUTPUT'),
  metasum                     CHAR(32),
  
  KEY file_anap_link_id_idx                      (file_anap_link_id),
  KEY file_anap_link_file_id_idx                 (file_id),
  KEY file_anap_link_analysis_parameter_id_idx   (analysis_parameter_id),
  UNIQUE KEY                                     (file_anap_link_id, file_id, analysis_parameter_id)
) ENGINE=MyISAM;
 

/**

@track table
@desc The table where the tracks are stored, with a link to the corresponding file.

@track_id               Track id (primary key, internal identifier).
@file_id                File table primary id (foreigh key).
@title                  Title of the track in E! genome browser.
@description            Description of the track in E! genome browser.
@metasum                Checksum of @title + @description.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE track (
  track_id              INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  file_id               INT(10),
  title                 TEXT,
  description           TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY track_id_idx                     (track_id),
  KEY track_analysis_param_id_idx      (file_id),
  UNIQUE KEY                           (track_id)
) ENGINE=MyISAM;

CREATE TRIGGER track_md5_upd_tr BEFORE UPDATE ON track
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.description) );
CREATE TRIGGER track_md5_ins_tr BEFORE INSERT ON track
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.description) );

/**

PUBLICATIONS TABLES

*/

/**

@publication table
@desc The table where the publication infos are stored.

@publication_id         Publication id (primary key, internal identifier).
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
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY publication_id_idx        (publication_id),
  KEY pubmed_id_idx             (pubmed_id),
  UNIQUE KEY                    (publication_id, pubmed_id)
) ENGINE=MyISAM;

CREATE TRIGGER publication_md5_upd_tr BEFORE UPDATE ON publication
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.abstract) );
CREATE TRIGGER publication_md5_ins_tr BEFORE INSERT ON publication
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.abstract) );

/**

@study_publication table
@desc Linker table between studies and publications.

@study_pub_link_id      Study-Publication link id (primary key, internal identifier).
@study_id               Study table primary id (foreign key).
@publication_id         Publication table primary id (foreign key).
@metasum                Checksum of @study_id + @pub_id.

*/

CREATE TABLE study_publication (
  study_pub_link_id     INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  study_id              INT(10),
  publication_id        INT(10),
  metasum               CHAR(32),
  
  KEY study_pub_link_id_idx   (study_pub_link_id),
  KEY study_pub_study_id_idx   (study_id),
  KEY study_pub_publication_id_idx   (publication_id),
  UNIQUE KEY                  (study_pub_link_id, study_id, publication_id)
) ENGINE=MyISAM;

CREATE TRIGGER study_publication_md5_upd_tr BEFORE UPDATE ON study_publication
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.study_id, NEW.publication_id) );
CREATE TRIGGER study_publication_md5_ins_tr BEFORE INSERT ON study_publication
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.study_id, NEW.publication_id) );

/**

DRUPAL TABLES

*/

/**

@drupal_node table
@desc Contains data that will be displayed in drupal nodes.

@drupal_node_id         Publication id (primary key, internal identifier).
@experiment_id          Experiment table primary id (foreign key).
@autogen_txt            Programmatically generated text.
@manual_txt             Manually curated text.
@metasum                Checksum of @autogen_txt + @manual_txt.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE drupal_node (
  drupal_node_id        INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  experiment_id         INT(10),
  autogen_txt           TEXT,
  manual_txt            TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY drupal_node_id_idx        (drupal_node_id),
  KEY experiment_id_idx         (experiment_id),
  UNIQUE KEY                    (drupal_node_id, experiment_id)
) ENGINE=MyISAM;

CREATE TRIGGER drupal_node_md5_upd_tr BEFORE UPDATE ON drupal_node
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.autogen_txt, NEW.manual_txt) );
CREATE TRIGGER drupal_node_md5_ins_tr BEFORE INSERT ON drupal_node
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.autogen_txt, NEW.manual_txt) );

