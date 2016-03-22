-- VectorBase RNAseq tracks database tables definitions


/**
@header SRA tables
@colour  #C70C09
*/


/**

SRA tracking tables

*/

/**

@table study
@desc Contains data defining SRA studies.

@column study_id           SRA study id (primary key, internal identifier).
@column study_sra_acc      SRA study accession (e.g. SRP000000).
@column study_private_acc  Private study accession (e.g. VBSRP000000), for data without SRA accessions.
@column title              Title of the SRA study.
@column abstract           Abstract of the SRA study.
@column metasum            Checksum of @study_sra_acc + @study_private_acc + @title + @abstract.
@column date               Entry timestamp.
@column status             Active (True) or retired (False) row.

*/

CREATE TABLE study (
  study_id           INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  study_sra_acc      CHAR(12) UNIQUE,
  study_private_acc  CHAR(12) UNIQUE,
  title              TEXT,
  abstract           TEXT,
  metasum            CHAR(32) UNIQUE,
  date               TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status             ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY study_id_idx        (study_id),
  KEY study_sra_acc_idx   (study_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER study_md5_upd_tr BEFORE UPDATE ON study
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.study_sra_acc, NEW.study_private_acc, NEW.title, NEW.abstract) );
CREATE TRIGGER study_md5_ins_tr BEFORE INSERT ON study
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.study_sra_acc, NEW.study_private_acc, NEW.title, NEW.abstract) );

/**

@table experiment
@desc Contains data defining SRA experiments.

@column experiment_id           SRA experiment id (primary key, internal identifier).
@column study_id                Study primary id (foreign key).
@column experiment_sra_acc      SRA experiment accession (e.g. SRX000000).
@column experiment_private_acc  Private experiment accession (e.g. VBSRX000000), for data without SRA accessions.
@column title                   Title of the SRA experiment.
@column metasum                 Checksum of @experiment_sra_acc + @experiment_private_acc + @title.
@column date                    Entry timestamp.
@column status                  Active (True) or retired (False) row.

*/

CREATE TABLE experiment (
  experiment_id          INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  study_id               INT(10) NOT NULL,
  experiment_sra_acc     CHAR(12) UNIQUE,
  experiment_private_acc CHAR(12) UNIQUE,
  title                  TEXT,
  metasum                CHAR(32) UNIQUE,
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY experiment_id_idx            (experiment_id),
  KEY experiment_study_id_idx      (study_id),
  KEY experiment_sra_acc_idx       (experiment_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER experiment_md5_upd_tr BEFORE UPDATE ON experiment
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.experiment_private_acc, NEW.experiment_sra_acc, NEW.title) );
CREATE TRIGGER experiment_md5_ins_tr BEFORE INSERT ON experiment
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.experiment_private_acc, NEW.experiment_sra_acc, NEW.title) );

/**

@table run
@desc Contains data defining SRA runs.

@column run_id                  SRA run id (primary key, internal identifier).
@column experiment_id           Experiment primary key (Foreign key).
@column sample_id               Sample primary key (Foreign key).
@column run_sra_acc             SRA run accession (e.g. SRR000000).
@column run_private_acc         Private run accession (e.g. VBSRR000000), for data without SRA accessions.
@column title                   Title of the SRA run.
@column submitter               Submitter name of the SRA run.
@column metasum                 Checksum of @run_sra_acc + @run_private_acc + @title + @submitter.
@column date                    Entry timestamp.
@column status                  Active (True) or retired (False) row.

*/

CREATE TABLE run (
  run_id                 INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  experiment_id          INT(10) NOT NULL,
  sample_id              INT(10) NOT NULL,
  run_sra_acc            CHAR(12) UNIQUE,
  run_private_acc        CHAR(12) UNIQUE,
  title                  TEXT,
  submitter              TEXT,
  metasum                CHAR(32) UNIQUE,
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY run_id_idx              (run_id),
  KEY run_experiment_id_idx   (experiment_id),
  KEY run_sample_id_idx       (sample_id),
  KEY run_sra_acc_idx         (run_sra_acc)
) ENGINE=MyISAM;

CREATE TRIGGER run_md5_upd_tr BEFORE UPDATE ON run
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.run_sra_acc, NEW.run_private_acc, NEW.title, NEW.submitter) );
CREATE TRIGGER run_md5_ins_tr BEFORE INSERT ON run
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.run_sra_acc, NEW.run_private_acc, NEW.title, NEW.submitter) );

/**

@table sample
@desc Contains data defining SRA samples.

@column sample_id               SRA sample id (primary key, internal identifier).
@column sample_sra_acc          SRA sample accession (e.g. SRS000000).
@column sample_private_acc      Private sample accession (e.g. VBSRS000000), for data without SRA accessions.
@column title                   Title of the SRA sample.
@column description             Description of the SRA sample.
@column taxon_id                NCBI taxon id.
@column strain                  Name of the strain.
@column biosample_acc           Biosample accession.
@column biosample_group_acc     Biosample group.
@column strain_id               Strain primary id (foreign key), to match the correct production_name.
@column label                   Label for the sample, useful to find replicates.
@column metasum                 Checksum of @sample_sra_acc + @sample_private_acc + @title + @description + @taxon_id + @strain + @biosample_acc + @biosample_group_acc + @label.
@column date                    Entry timestamp.
@column status                  Active (True) or retired (False) row.

*/

CREATE TABLE sample (
  sample_id                 INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  sample_sra_acc            CHAR(12) UNIQUE,
  sample_private_acc        CHAR(12) UNIQUE,
  title                     TEXT,
  description               TEXT,
  taxon_id                  INT(10),
  strain                    TEXT,
  biosample_acc             VARCHAR(15) UNIQUE,
  biosample_group_acc       VARCHAR(15),
  strain_id                 INT(10) NOT NULL,
  label                     TEXT,
  metasum                   CHAR(32) UNIQUE,
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY sample_id_idx              (sample_id),
  KEY sample_sra_acc_idx         (sample_sra_acc),
  KEY biosample_acc_idx          (biosample_acc),
  KEY biosample_group_acc_idx    (biosample_group_acc)
) ENGINE=MyISAM;

CREATE TRIGGER sample_md5_upd_tr BEFORE UPDATE ON sample
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.sample_sra_acc, NEW.sample_private_acc, NEW.title, NEW.description, NEW.taxon_id, NEW.strain, NEW.biosample_acc, NEW.biosample_group_acc, NEW.label) );
CREATE TRIGGER sample_md5_ins_tr BEFORE INSERT ON sample
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.sample_sra_acc, NEW.sample_private_acc, NEW.title, NEW.description, NEW.taxon_id, NEW.strain, NEW.biosample_acc, NEW.biosample_group_acc, NEW.label) );


/**
@header Taxonomy tables
@colour #CC75FF
*/

/**

@table species
@desc A list of all existing species.

@column species_id              Species id (primary key, internal identifier).
@column taxon_id                NCBI species id.
@column binomial_name           Species binomial name.
@column metasum                 Checksum of @binomial_name + @taxon.
@column date                    Entry timestamp.
@column status                  Active (True) or retired (False) row.

*/

CREATE TABLE species (
  species_id                INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  taxon_id                  INT(10) UNIQUE,
  binomial_name             VARCHAR(128),
  metasum                   CHAR(32) UNIQUE,
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY species_id_idx              (species_id)
) ENGINE=MyISAM;

CREATE TRIGGER species_md5_upd_tr BEFORE UPDATE ON species
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.binomial_name, NEW.taxon_id) );
CREATE TRIGGER species_md5_ins_tr BEFORE INSERT ON species
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.binomial_name, NEW.taxon_id) );
 
/**
@table strain
@desc A list of all existing (allowed) strains.

@column strain_id               Strain id (primary key, internal identifier).
@column species_id        Species primary key (foreign key).
@column production_name         Production name for this strain (species + strain).
@column strain                  Name of the strain.
@column metasum                 Checksum of @production_name + @strain.
@column date                    Entry timestamp.
@column status                  Active (True) or retired (False) row.

*/

CREATE TABLE strain (
  strain_id                 INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  species_id                INT(10),
  production_name           VARCHAR(64) NOT NULL,
  strain                    VARCHAR(32),
  metasum                   CHAR(32) UNIQUE,
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY strain_id_idx              (strain_id)
) ENGINE=MyISAM;

CREATE TRIGGER strain_md5_upd_tr BEFORE UPDATE ON strain
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.production_name, NEW.strain) );
CREATE TRIGGER strain_md5_ins_tr BEFORE INSERT ON strain
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.production_name, NEW.strain) );

    
CREATE VIEW taxonomy AS
  SELECT binomial_name,
         taxon_id,
         production_name,
        strain,
        strain_id,
        strain.status AS status
  FROM strain LEFT JOIN species
    USING(species_id)
;

/**

PIPELINE TABLES

*/
/**
@header RNAseq Pipeline tables
@colour #FF7504
*/
/**


/**

@table file
@desc Where all metadata about the files are stored.

@column file_id                File id (primary key, internal identifier).
@column path                   Path of the file.
@column type                   File type (fastq, bam...).
@column md5                    md5 checksum of the file.
@column metasum                Checksum of @path + @type + @md5.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE file (
  file_id               INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  path                  TEXT NOT NULL,
  type                  ENUM('fastq', 'bam', 'bai', 'bed', 'bigwig'),
  md5                   CHAR(32),
  metasum               CHAR(32) UNIQUE,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY file_id_idx            (file_id)
) ENGINE=MyISAM;

CREATE TRIGGER file_md5_upd_tr BEFORE UPDATE ON file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.path, NEW.type, NEW.md5) );
CREATE TRIGGER file_md5_ins_tr BEFORE INSERT ON file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.path, NEW.type, NEW.md5) );

/**

@table analysis
@desc Where all the analysis to create tracks are described.

@column analysis_id            Analysis id (primary key, internal identifier).
@column name                   Name of the analysis.
@column description            Description of the analysis.
@column metasum                Checksum of @name + @description.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE analysis (
  analysis_id           INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  name                  VARCHAR(32) UNIQUE,
  description           TEXT,
  metasum               CHAR(32) UNIQUE,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY analysis_id_idx      (analysis_id)
) ENGINE=MyISAM;

CREATE TRIGGER analysis_md5_upd_tr BEFORE UPDATE ON analysis
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.name, NEW.description) );
CREATE TRIGGER analysis_md5_ins_tr BEFORE INSERT ON analysis
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.name, NEW.description) );

/**

@table analysis_param
@desc Where the analysis parameters used to process every files are stored.

@column analysis_param_id      Analysis parameters id (primary key, internal identifier).
@column analysis_id            Analysis primary id (foreigh key).
@column program                Name of the Program used.
@column parameters             Complete command line parameters used.
@column metasum                Checksum of @program + @parameters.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE analysis_param (
  analysis_param_id     INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  analysis_id           INT(10),
  program               TEXT,
  parameters            TEXT,
  metasum               CHAR(32) UNIQUE,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY analysis_param_id_idx            (analysis_param_id),
  KEY analysis_param_analysis_id_idx   (analysis_id)
) ENGINE=MyISAM;

CREATE TRIGGER analysis_param_md5_upd_tr BEFORE UPDATE ON analysis_param
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.program, NEW.parameters) );
CREATE TRIGGER analysis_param_md5_ins_tr BEFORE INSERT ON analysis_param
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.program, NEW.parameters) );

/**

@table analysis_file
@desc Linker between the tables file and analysis_parameter. Also links to the relevant runs and samples.

@column analysis_file_id             Analysis-file linker id (primary key, internal identifier).
@column analysis_parameter_id        Analysis_parameter primary id (foreigh key).
@column file_id                      File primary id (foreign key).
@column file_io                      If the file is an input or an output.
@column scope                        Does the file represents a run, or a sample (merged)?
@column scope_id                     Run or Sample primary id (foreign key).
@column metasum                      Checksum of @analysis_parameter_id + @file_id + @file_io + @scope + @scope_id

*/

CREATE TABLE analysis_file (
  analysis_file_id            INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  analysis_parameter_id       INT(10),
  file_id                     INT(10),
  file_io                     ENUM('INPUT', 'OUTPUT'),
  scope                       ENUM('run', 'sample'),
  scope_id                    INT(10),
  metasum                     CHAR(32) UNIQUE,
  
  KEY analysis_file_id_idx                      (analysis_file_id),
  KEY analysis_file_analysis_parameter_id_idx   (analysis_parameter_id),
  KEY analysis_file_file_id_idx                 (file_id),
  KEY analysis_file_scope_id_idx                (scope_id)
) ENGINE=MyISAM;

CREATE TRIGGER analysis_file_md5_upd_tr BEFORE UPDATE ON analysis_file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.analysis_parameter_id, NEW.file_id, NEW.file_io, NEW.scope, NEW.scope_id) );
CREATE TRIGGER analysis_file_md5_ins_tr BEFORE INSERT ON analysis_file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.analysis_parameter_id, NEW.file_id, NEW.file_io, NEW.scope, NEW.scope_id) );


/**

@header Tracks tables
@colour #3355FF

*/

/**

@table track
@desc Where the tracks are stored, with a link to the corresponding file and sample.

@column track_id               Track id (primary key, internal identifier).
@column file_id                File primary id (foreigh key).
@column title                  Title of the track in E! genome browser.
@column description            Description of the track in E! genome browser.
@column metasum                Checksum of @title + @description.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE track (
  track_id              INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  file_id               INT(10) UNIQUE,
  title                 TEXT,
  description           TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY track_id_idx                     (track_id),
  KEY track_file_id_idx                (file_id)
) ENGINE=MyISAM;

CREATE TRIGGER track_md5_upd_tr BEFORE UPDATE ON track
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.track_id, NEW.title, NEW.description) );
CREATE TRIGGER track_md5_ins_tr BEFORE INSERT ON track
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.track_id, NEW.title, NEW.description) );

/**
@table sra_track
@desc Defines what constitutes a track, i.e. one or several samples.

@column sra_track_id           Track id (primary key, internal identifier).
@column sample_id              SRA sample primary id (foreigh key).
@column track_id               Track table primary id (foreign key).
@column date                   Entry timestamp.

*/

CREATE TABLE sra_track (
  sra_track_id          INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  sample_id             INT(10),
  track_id              INT(10),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY sra_track_id_idx                 (sra_track_id),
  KEY sra_track_sample_id_idx          (sample_id),
  KEY sra_track_track_id_idx           (track_id)
) ENGINE=MyISAM;

/**
@header Misc tables
@colour #55FF33
*/
/**

/**

PUBLICATIONS TABLES

*/

/**

@table publication
@desc Where the publication infos are stored.

@column publication_id         Publication id (primary key, internal identifier) PRIMARY KEY.
@column pubmed_id              Pubmed id.
@column doi                    Digital object identifier.
@column authors                List of authors.
@column title                  Title of the publication.
@column abstract               Abstract of the publication.
@column year                   Year of publication.
@column metasum                Checksum of @pubmed_id + @doi + @authors + @title + @abstract + @year.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE publication (
  publication_id        INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  pubmed_id             INT(10) UNIQUE,
  doi                   VARCHAR(32),
  authors               TEXT,
  title                 TEXT,
  abstract              TEXT,
  year                  INT(4),
  metasum               CHAR(32) UNIQUE,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY publication_id_idx        (publication_id),
  KEY pubmed_id_idx             (pubmed_id)
) ENGINE=MyISAM;

CREATE TRIGGER publication_md5_upd_tr BEFORE UPDATE ON publication
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.pubmed_id, NEW.doi, NEW.authors, NEW.title, NEW.abstract, NEW.year) );
CREATE TRIGGER publication_md5_ins_tr BEFORE INSERT ON publication
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.pubmed_id, NEW.doi, NEW.authors, NEW.title, NEW.abstract, NEW.year) );

/**

@table study_publication
@desc Linker between studies and publications.

@column study_pub_id          Study-Publication link id (primary key, internal identifier).
@column study_id              Study primary id (foreign key).
@column publication_id        Publication primary id (foreign key).

*/

CREATE TABLE study_publication (
  study_pub_id          INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
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

@table drupal_node
@desc Contains data that will be displayed in drupal nodes.

@column drupal_node_id         Publication id (primary key, internal identifier).
@column study_id               Study primary id (foreign key).
@column autogen_txt            Programmatically generated text.
@column manual_txt             Manually curated text.
@column metasum                Checksum of @autogen_txt + @manual_txt.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE drupal_node (
  drupal_node_id        INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  study_id              INT(10) UNIQUE,
  autogen_txt           TEXT,
  manual_txt            TEXT,
  metasum               CHAR(32) UNIQUE,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY drupal_node_id_idx        (drupal_node_id),
  KEY study_id_idx              (study_id)
) ENGINE=MyISAM;

CREATE TRIGGER drupal_node_md5_upd_tr BEFORE UPDATE ON drupal_node
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.autogen_txt, NEW.manual_txt) );
CREATE TRIGGER drupal_node_md5_ins_tr BEFORE INSERT ON drupal_node
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.autogen_txt, NEW.manual_txt) );

