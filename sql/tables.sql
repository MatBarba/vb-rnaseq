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
@desc The study table contains data defining SRA studies.

@study_id           SRA study id (primary key, internal identifier).
@study_sra_acc      SRA study accession (e.g. SRP000000).
@title              Title of the SRA study.
@abstract           Abstract of the SRA study.
@metasum            Checksum of @title + @abstract.
@date               Entry timestamp.
@status             Active (True) or retired (False) row.

*/

CREATE TABLE study (
  study_id          INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  study_sra_acc     CHAR(12) NOT NULL UNIQUE,
  title             TEXT,
  abstract          TEXT,
  metasum           CHAR(32),
  date              TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status            ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY study_id_idx        (study_id),
  KEY study_sra_acc_idx   (study_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER study_md5_upd_tr BEFORE UPDATE ON study
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.abstract) );
CREATE TRIGGER study_md5_ins_tr BEFORE INSERT ON study
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.abstract) );

/**

@experiment table
@desc The experiment table contains data defining SRA experiments.

@experiment_id           SRA experiment id (primary key, internal identifier).
@study_id                Study table primary id (foreign key).
@experiment_sra_acc      SRA experiment accession (e.g. SRX000000).
@title                   Title of the SRA experiment.
@metasum                 Checksum of @title.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE experiment (
  experiment_id          INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  study_id               INT(10) NOT NULL,
  experiment_sra_acc     CHAR(12) NOT NULL UNIQUE,
  title                  TEXT,
  metasum                CHAR(32),
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY experiment_id_idx            (experiment_id),
  KEY experiment_study_id_idx      (study_id),
  KEY experiment_sra_acc_idx       (experiment_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER experiment_md5_upd_tr BEFORE UPDATE ON experiment
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title) );
CREATE TRIGGER experiment_md5_ins_tr BEFORE INSERT ON experiment
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title) );

/**

@run table
@desc The run table contains data defining SRA runs.

@run_id                  SRA run id (primary key, internal identifier).
@experiment_id           Experiment table primary key (Foreign key).
@sample_id               Sample table primary key (Foreign key).
@run_sra_acc             SRA run accession (e.g. SRR000000).
@title                   Title of the SRA run.
@submitter               Submitter id of the SRA run.
@metasum                 Checksum of @title + @submitter.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE run (
  run_id                 INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  experiment_id          INT(10) NOT NULL,
  sample_id              INT(10) NOT NULL,
  run_sra_acc            CHAR(12) NOT NULL UNIQUE,
  title                  TEXT,
  submitter              TEXT,
  metasum                CHAR(32),
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY run_id_idx              (run_id),
  KEY run_experiment_id_idx   (experiment_id),
  KEY run_sample_id_idx       (sample_id),
  KEY run_sra_acc_idx         (run_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER run_md5_upd_tr BEFORE UPDATE ON run
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.submitter) );
CREATE TRIGGER run_md5_ins_tr BEFORE INSERT ON run
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.submitter) );

/**

@sample table
@desc The sample table contains data defining SRA samples.

@sample_id               SRA sample id (primary key, internal identifier).
@sample_sra_acc          SRA sample accession (e.g. SRS000000).
@title                   Title of the SRA sample.
@taxon_id                NCBI taxon id.
@strain                  Name of the strain.
@metasum                 Checksum of @title.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE sample (
  sample_id                 INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  sample_sra_acc            CHAR(12) NOT NULL UNIQUE,
  title                     TEXT,
  taxon_id                  INT(10),
  strain                    TEXT,
  metasum                   CHAR(32),
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY sample_id_idx              (sample_id),
  KEY sample_sra_acc_idx         (sample_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER sample_md5_upd_tr BEFORE UPDATE ON sample
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.taxon_id, NEW.strain) );
CREATE TRIGGER sample_md5_ins_tr BEFORE INSERT ON sample
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.title, NEW.taxon_id, NEW.strain) );

/**

@species table
@desc A list of all existing (allowed) species, with the corresponding production names.

@species_id              Species id (primary key, internal identifier).
@production_name         Production name for this species (species + strain).
@taxon_id                NCBI species id.
@strain                  Name of the strain.
@metasum                 Checksum of @species_name + @taxon + @strain.
@date                    Entry timestamp.
@status                  Active (True) or retired (False) row.

*/

CREATE TABLE species (
  species_id                INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  production_name           VARCHAR(64) NOT NULL UNIQUE,
  taxon_id                  INT(10),
  strain                    VARCHAR(32),
  metasum                   CHAR(32),
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY species_id_idx              (species_id),
  UNIQUE KEY                      (taxon_id, strain)
) ENGINE=MyISAM;

CREATE TRIGGER species_md5_upd_tr BEFORE UPDATE ON species
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.production_name, NEW.taxon_id, NEW.strain) );
CREATE TRIGGER species_md5_ins_tr BEFORE INSERT ON species
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.production_name, NEW.taxon_id, NEW.strain) );


/**

PIPELINE TABLES

*/

/**

@file table
@desc The table where all metadata about the files are stored.

@file_id                File id (primary key, internal identifier).
@path                   Path of the file.
@type                   File type (fastq, bam...).
@md5                    md5 checksum of the file.
@metasum                Checksum of @path + @type + @md5.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE file (
  file_id               INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  path                  TEXT NOT NULL,
  type                  ENUM('fastq', 'bam', 'bai', 'bed', 'bigwig'),
  md5                   CHAR(32),
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY file_id_idx            (file_id)
) ENGINE=MyISAM;

CREATE TRIGGER file_md5_upd_tr BEFORE UPDATE ON file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.path, NEW.type, NEW.md5) );
CREATE TRIGGER file_md5_ins_tr BEFORE INSERT ON file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.path, NEW.type, NEW.md5) );

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
  analysis_id           INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  name                  VARCHAR(32) UNIQUE,
  description           TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY analysis_id_idx      (analysis_id)
) ENGINE=MyISAM;

CREATE TRIGGER analysis_md5_upd_tr BEFORE UPDATE ON analysis
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.name, NEW.description) );
CREATE TRIGGER analysis_md5_ins_tr BEFORE INSERT ON analysis
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.name, NEW.description) );

/**

@analysis_param table
@desc The table where the analysis parameters used to process every files are stored.

@analysis_param_id      Analysis parameters id (primary key, internal identifier).
@analysis_id            Analysis table primary id (foreigh key).
@program                Name of the Program used.
@parameters             Complete command line parameters used.
@metasum                Checksum of @program + @parameters.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE analysis_param (
  analysis_param_id     INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  analysis_id           INT(10),
  program               TEXT,
  parameters            TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY analysis_param_id_idx            (analysis_param_id),
  KEY analysis_param_analysis_id_idx   (analysis_id)
) ENGINE=MyISAM;

CREATE TRIGGER analysis_param_md5_upd_tr BEFORE UPDATE ON analysis_param
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.program, NEW.parameters) );
CREATE TRIGGER analysis_param_md5_ins_tr BEFORE INSERT ON analysis_param
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.program, NEW.parameters) );

/**

@analysis_file table
@desc Linker between the tables file and analysis_parameter. Also links to the relevant runs and samples.

@analysis_file_id             Analysis-file linker id (primary key, internal identifier).
@analysis_parameter_id        Analysis_parameter table primary id (foreigh key).
@file_id                      File table primary id (foreign key).
@file_io                      If the file is an input or an output.
@scope                        Does the file represents a run, or a sample (merged)?
@scope_id                     Run or Sample table primary id (foreign key).
@metasum                      Checksum of @analysis_parameter_id + @file_id + @file_io + @scope + @scope_id

*/

CREATE TABLE analysis_file (
  analysis_file_id            INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  analysis_parameter_id       INT(10),
  file_id                     INT(10),
  file_io                     ENUM('INPUT', 'OUTPUT'),
  scope                       ENUM('run', 'sample'),
  scope_id                    INT(10),
  metasum                     CHAR(32),
  
  KEY analysis_file_id_idx                      (analysis_file_id),
  KEY analysis_file_analysis_parameter_id_idx   (analysis_parameter_id),
  KEY analysis_file_file_id_idx                 (file_id),
  KEY analysis_file_scope_id_idx                (scope_id)
) ENGINE=MyISAM;

CREATE TRIGGER analysis_file_md5_upd_tr BEFORE UPDATE ON analysis_file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.analysis_parameter_id, NEW.file_id, NEW.file_io, NEW.scope, NEW.scope_id) );
CREATE TRIGGER analysis_file_md5_ins_tr BEFORE INSERT ON analysis_file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.analysis_parameter_id, NEW.file_id, NEW.file_io, NEW.scope, NEW.scope_id) );

/**

@track table
@desc The table where the tracks are stored, with a link to the corresponding file and sample.

@track_id               Track id (primary key, internal identifier).
@file_id                File table primary id (foreigh key).
@sample_id              Sample table primary key (foreign key).
@title                  Title of the track in E! genome browser.
@description            Description of the track in E! genome browser.
@metasum                Checksum of @title + @description.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE track (
  track_id              INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  file_id               INT(10) NOT NULL UNIQUE,
  sample_id             INT(10) NOT NULL,
  title                 TEXT,
  description           TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY track_id_idx                     (track_id),
  KEY track_file_id_idx                (file_id),
  KEY track_sample_id_idx              (sample_id)
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
@metasum                Checksum of @pubmed_id + @doi + @authors + @title + @abstract + @year.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE publication (
  publication_id        INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  pubmed_id             INT(10) UNIQUE,
  doi                   VARCHAR(32),
  authors               TEXT,
  title                 TEXT,
  abstract              TEXT,
  year                  INT(4),
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY publication_id_idx        (publication_id),
  KEY pubmed_id_idx             (pubmed_id)
) ENGINE=MyISAM;

CREATE TRIGGER publication_md5_upd_tr BEFORE UPDATE ON publication
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.pubmed_id, NEW.doi, NEW.authors, NEW.title, NEW.abstract, NEW.year) );
CREATE TRIGGER publication_md5_ins_tr BEFORE INSERT ON publication
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.pubmed_id, NEW.doi, NEW.authors, NEW.title, NEW.abstract, NEW.year) );

/**

@study_publication table
@desc Linker table between studies and publications.

@study_pub_id          Study-Publication link id (primary key, internal identifier).
@study_id              Study table primary id (foreign key).
@publication_id        Publication table primary id (foreign key).

*/

CREATE TABLE study_publication (
  study_pub_id          INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  study_id              INT(10) NOT NULL,
  publication_id        INT(10) NOT NULL,
  
  KEY study_pub_id_idx                (study_pub_id),
  KEY study_pub_study_id_idx          (study_id),
  KEY study_pub_publication_id_idx    (publication_id)
) ENGINE=MyISAM;

/**

DRUPAL TABLES

*/

/**

@drupal_node table
@desc Contains data that will be displayed in drupal nodes.

@drupal_node_id         Publication id (primary key, internal identifier).
@study_id               Study table primary id (foreign key).
@autogen_txt            Programmatically generated text.
@manual_txt             Manually curated text.
@metasum                Checksum of @autogen_txt + @manual_txt.
@date                   Entry timestamp.
@status                 Active (True) or retired (False) row.

*/

CREATE TABLE drupal_node (
  drupal_node_id        INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT,
  study_id              INT(10) UNIQUE,
  autogen_txt           TEXT,
  manual_txt            TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY drupal_node_id_idx        (drupal_node_id),
  KEY study_id_idx              (study_id)
) ENGINE=MyISAM;

CREATE TRIGGER drupal_node_md5_upd_tr BEFORE UPDATE ON drupal_node
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.autogen_txt, NEW.manual_txt) );
CREATE TRIGGER drupal_node_md5_ins_tr BEFORE INSERT ON drupal_node
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT(NEW.autogen_txt, NEW.manual_txt) );

