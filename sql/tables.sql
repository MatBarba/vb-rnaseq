-- VectorBase RNAseq tracks database tables definitions


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
  taxon_id                  INT(10) UNSIGNED UNIQUE,
  binomial_name             VARCHAR(128),
  metasum                   CHAR(32) UNIQUE,
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY species_id_idx              (species_id)
) ENGINE=InnoDB;

CREATE TRIGGER species_md5_upd_tr BEFORE UPDATE ON species
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.binomial_name, NEW.taxon_id) );
CREATE TRIGGER species_md5_ins_tr BEFORE INSERT ON species
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.binomial_name, NEW.taxon_id) );
 
/**
@table strain
@desc A list of all existing (allowed) strains.

@column strain_id               Strain id (primary key, internal identifier).
@column species_id              Species primary key (foreign key).
@column production_name         Production name for this strain (species + strain).
@column strain                  Name of the strain.
@column assembly                Version of the assembly.
@column assembly_accession      Version of the assembly in INSDC.
@column metasum                 Checksum of @production_name + @strain.
@column date                    Entry timestamp.
@column status                  Active (True) or retired (False) row.

*/

CREATE TABLE strain (
  strain_id                 INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  species_id                INT(10) UNSIGNED NOT NULL,
  production_name           VARCHAR(64) NOT NULL,
  strain                    VARCHAR(32),
  assembly                  VARCHAR(32),
  assembly_accession        VARCHAR(32),
  metasum                   CHAR(32) UNIQUE,
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  FOREIGN KEY(species_id) REFERENCES species(species_id),
  
  KEY strain_id_idx              (strain_id)
) ENGINE=InnoDB;

CREATE TRIGGER strain_md5_upd_tr BEFORE UPDATE ON strain
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.production_name, NEW.strain, NEW.assembly, NEW.assembly_accession) );
CREATE TRIGGER strain_md5_ins_tr BEFORE INSERT ON strain
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.production_name, NEW.strain, NEW.assembly, NEW.assembly_accession) );

    
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
  study_id           INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  study_sra_acc      CHAR(12) UNIQUE,
  study_private_acc  CHAR(12) UNIQUE,
  title              TEXT,
  abstract           TEXT,
  metasum            CHAR(32) UNIQUE,
  date               TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status             ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY study_id_idx        (study_id),
  KEY study_sra_acc_idx   (study_sra_acc)
) ENGINE=InnoDB;

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
  experiment_id          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  study_id               INT(10) UNSIGNED NOT NULL,
  experiment_sra_acc     CHAR(12) UNIQUE,
  experiment_private_acc CHAR(12) UNIQUE,
  title                  TEXT,
  metasum                CHAR(32) UNIQUE,
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  FOREIGN KEY(study_id) REFERENCES study(study_id),
  
  KEY experiment_id_idx            (experiment_id),
  KEY experiment_study_id_idx      (study_id),
  KEY experiment_sra_acc_idx       (experiment_sra_acc)
) ENGINE=InnoDB;

CREATE TRIGGER experiment_md5_upd_tr BEFORE UPDATE ON experiment
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.experiment_private_acc, NEW.experiment_sra_acc, NEW.title) );
CREATE TRIGGER experiment_md5_ins_tr BEFORE INSERT ON experiment
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.experiment_private_acc, NEW.experiment_sra_acc, NEW.title) );

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
@column strain_id               Strain primary id (foreign key), to match the correct production_name.
@column biosample_acc           Biosample accession.
@column biosample_group_acc     Biosample group.
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
  taxon_id                  INT(10) UNSIGNED,
  strain                    TEXT,
  strain_id                 INT(10) UNSIGNED NOT NULL,
  biosample_acc             VARCHAR(15) UNIQUE,
  biosample_group_acc       VARCHAR(15),
  label                     TEXT,
  metasum                   CHAR(32) UNIQUE,
  date                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                    ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  FOREIGN KEY(strain_id) REFERENCES strain(strain_id),
  
  KEY sample_id_idx              (sample_id),
  KEY sample_sra_acc_idx         (sample_sra_acc),
  KEY biosample_acc_idx          (biosample_acc),
  KEY biosample_group_acc_idx    (biosample_group_acc)
) ENGINE=InnoDB;

CREATE TRIGGER sample_md5_upd_tr BEFORE UPDATE ON sample
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.sample_sra_acc, NEW.sample_private_acc, NEW.title, NEW.description, NEW.taxon_id, NEW.strain, NEW.biosample_acc, NEW.biosample_group_acc, NEW.label) );
CREATE TRIGGER sample_md5_ins_tr BEFORE INSERT ON sample
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.sample_sra_acc, NEW.sample_private_acc, NEW.title, NEW.description, NEW.taxon_id, NEW.strain, NEW.biosample_acc, NEW.biosample_group_acc, NEW.label) );

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
  experiment_id          INT(10) UNSIGNED NOT NULL,
  sample_id              INT(10) UNSIGNED NOT NULL,
  run_sra_acc            CHAR(12) UNIQUE,
  run_private_acc        CHAR(12) UNIQUE,
  title                  TEXT,
  submitter              TEXT,
  metasum                CHAR(32) UNIQUE,
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),
  FOREIGN KEY(sample_id) REFERENCES sample(sample_id),
  
  KEY run_id_idx              (run_id),
  KEY run_experiment_id_idx   (experiment_id),
  KEY run_sample_id_idx       (sample_id),
  KEY run_sra_acc_idx         (run_sra_acc)
) ENGINE=InnoDB;

CREATE TRIGGER run_md5_upd_tr BEFORE UPDATE ON run
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.run_sra_acc, NEW.run_private_acc, NEW.title, NEW.submitter) );
CREATE TRIGGER run_md5_ins_tr BEFORE INSERT ON run
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.run_sra_acc, NEW.run_private_acc, NEW.title, NEW.submitter) );

/**

@table private_file
@desc Stores the files used for private runs (not in SRA).

@column private_file_id         Private_file id (primary key, internal identifier).
@column run_id                  Run primary key (Foreign key).
@column path                    File path.
@column md5                     Md5sum of the file.
@column metasum                 Checksum of @run_id + @path.
@column date                    Entry timestamp.
@column status                  Active (True) or retired (False) row.

*/

CREATE TABLE private_file (
  private_file_id        INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  run_id                 INT(10) UNSIGNED NOT NULL,
  path                   TEXT,
  md5                    CHAR(32) UNIQUE,
  metasum                CHAR(32) UNIQUE,
  date                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                 ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  FOREIGN KEY(run_id) REFERENCES run(run_id),
  
  KEY private_file_id_idx              (private_file_id),
  KEY private_file_run_id_idx          (run_id)
) ENGINE=InnoDB;

CREATE TRIGGER private_file_md5_upd_tr BEFORE UPDATE ON private_file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.run_id, NEW.path) );
CREATE TRIGGER private_file_md5_ins_tr BEFORE INSERT ON private_file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.run_id, NEW.path) );


/**

@header Tracks tables
@colour #3355FF

*/

/**

@table track
@desc Where the tracks are stored, with a link to the corresponding file.

@column track_id               Track id (primary key, internal identifier).
@column title_auto             Title of the track in E! genome browser (automatically created).
@column description_auto       Description of the track in E! genome browser (automatically created).
@column title_manual           Title of the track in E! genome browser (manually created).
@column description_manual     Description of the track in E! genome browser (manually created).
@column merge_level            Merge level for the set of runs for the pipeline.
@column merge_id               Merge id generated for this track.
@column merge_text             Merge text (text used to create the merge_id hash).
@column metasum                Checksum of @title + @description.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE track (
  track_id              INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  title_auto            TEXT,
  description_auto      TEXT,
  title_manual          TEXT,
  description_manual    TEXT,
  merge_level           ENUM('taxon', 'study', 'experiment', 'run', 'sample'),
  merge_id              VARCHAR(256) UNIQUE,
  merge_text            TEXT,
  metasum               CHAR(32),
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED', 'MERGED') DEFAULT 'ACTIVE',
  
  KEY track_id_idx                     (track_id)
) ENGINE=InnoDB;

CREATE TRIGGER track_md5_upd_tr BEFORE UPDATE ON track
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.track_id, NEW.title_auto, NEW.description_auto, NEW.title_manual, NEW.description_manual, NEW.merge_id, NEW.merge_text) );
CREATE TRIGGER track_md5_ins_tr BEFORE INSERT ON track
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.track_id, NEW.title_auto, NEW.description_auto, NEW.title_manual, NEW.description_manual, NEW.merge_id, NEW.merge_text) );

/**
@table sra_track
@desc Defines what constitutes a track, i.e. one or several runs.

@column sra_track_id           Track id (primary key, internal identifier).
@column run_id                 SRA run primary id (foreign key).
@column track_id               Track table primary id (foreign key).
@column date                   Entry timestamp.

*/

CREATE TABLE sra_track (
  sra_track_id          INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  run_id                INT(10) UNSIGNED NOT NULL,
  track_id              INT(10) UNSIGNED NOT NULL,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY(run_id) REFERENCES run(run_id),
  FOREIGN KEY(track_id) REFERENCES track(track_id),
  
  KEY sra_track_id_idx                 (sra_track_id),
  KEY sra_track_run_id_idx             (run_id),
  KEY sra_track_track_id_idx           (track_id)
) ENGINE=InnoDB;

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
@column track_id               Track primary id (foreign key).
@column path                   Path of the file.
@column type                   File type (fastq, bam...).
@column md5                    md5 checksum of the file.
@column metasum                Checksum of @path + @type + @md5.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE file (
  file_id               INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  track_id              INT(10) UNSIGNED NOT NULL,
  path                  TEXT NOT NULL,
  type                  ENUM('fastq', 'bam', 'bai', 'bed', 'bigwig'),
  md5                   CHAR(32),
  metasum               CHAR(32) UNIQUE,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  FOREIGN KEY(track_id) REFERENCES track(track_id),
  
  KEY file_id_idx         (file_id),
  KEY file_track_id_idx   (track_id)
) ENGINE=InnoDB;

CREATE TRIGGER file_md5_upd_tr BEFORE UPDATE ON file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.path, NEW.type, NEW.md5) );
CREATE TRIGGER file_md5_ins_tr BEFORE INSERT ON file
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.path, NEW.type, NEW.md5) );

/**

@table analysis_description
@desc Where all the analysis to create tracks are described.

@column analysis_description_id  Analysis id (primary key, internal identifier).
@column name                     Name of the analysis.
@column description              Description of the analysis.
@column type                     What kind of operation is performed.
@column pattern                  Regexp to recognize the program from the command.
@column metasum                  Checksum of @name + @description.
@column date                     Entry timestamp.
@column status                   Active (True) or retired (False) row.

*/

CREATE TABLE analysis_description (
  analysis_description_id     INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  name                        VARCHAR(32) UNIQUE,
  description                 TEXT,
  type                        enum('aligner', 'indexer', 'converter', 'modifier', 'analyser'),
  pattern                     TEXT,
  metasum                     CHAR(32) UNIQUE,
  date                        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                      ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY analysis_description_id_idx      (analysis_description_id)
) ENGINE=InnoDB;

CREATE TRIGGER analysis_description_md5_upd_tr BEFORE UPDATE ON analysis_description
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.name, NEW.description, NEW.type, NEW.pattern) );
CREATE TRIGGER analysis_description_md5_ins_tr BEFORE INSERT ON analysis_description
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.name, NEW.description, NEW.type, NEW.pattern) );

INSERT INTO analysis_description (type, name, description, pattern) VALUES
  ('aligner',   'bowtie2',     'Bowtie2 aligner',                     '^bowtie2 '),
  ('aligner',   'bwa',         'Bwa aligner',                         '^bwa '),
  ('aligner',   'star',        'STAR aligner',                        '^star '),
  ('aligner',   'hisat2',      'Hisat2 aligner',                      '^hisat2 '),
  ('indexer',   'bam_index',   'Bam index with samtools',             '^samtools index'),
  ('indexer',   'hisat2_build ',   'Hisat2 index builder',             '^hisat2-build'),
  ('converter', 'sam2bam',     'Convert file from SAM to BAM format', '^samtools view -bS'),
  ('converter', 'bam2wig',     'Convert BAM to coverage file WIG',    '^bedtools genomecov'),
  ('converter', 'wig2bigwig',  'Convert WIG to BIGWIG',               '^wigToBigWig'),
  ('modifier',  'bam_merge',   'Merge BAM files',                     '^samtools merge'),
  ('modifier',  'bam_sort',    'Sort a BAM file',                     '^samtools sort')
;
  
/**

@table analysis
@desc Where the analysis parameters used to process every files are stored.

@column analysis_id              Analysis parameters id (primary key, internal identifier).
@column analysis_description_id  Analysis description primary id (foreigh key).
@column track_id                 Track primary id (foreign key).
@column version                  Version of the program used.
@column command                  Complete command line parameters used.
@column metasum                  Checksum of @program + @parameters.
@column date                     Entry timestamp.
@column status                   Active (True) or retired (False) row.

*/

CREATE TABLE analysis (
  analysis_id              INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  analysis_description_id  INT(10) UNSIGNED,
  track_id                 INT(10) UNSIGNED NOT NULL,
  version                  TEXT,
  command                  TEXT,
  metasum                  CHAR(32),
  date                     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                   ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  FOREIGN KEY(analysis_description_id) REFERENCES analysis_description(analysis_description_id),
  FOREIGN KEY(track_id) REFERENCES track(track_id),
  
  KEY analysis_id_idx              (analysis_id),
  KEY analysis_description_id_idx  (analysis_description_id),
  KEY analysis_track_id_idx        (track_id)
) ENGINE=InnoDB;

CREATE TRIGGER analysis_md5_upd_tr BEFORE UPDATE ON analysis
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.version, NEW.command) );
CREATE TRIGGER analysis_md5_ins_tr BEFORE INSERT ON analysis
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.version, NEW.command) );


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
  pubmed_id             INT(10) UNSIGNED UNIQUE,
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
) ENGINE=InnoDB;

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
  study_id              INT(10) UNSIGNED NOT NULL,
  publication_id        INT(10) UNSIGNED NOT NULL,
  
  FOREIGN KEY(study_id) REFERENCES study(study_id),
  FOREIGN KEY(publication_id) REFERENCES publication(publication_id),
  
  KEY study_pub_id_idx                (study_pub_id),
  KEY study_pub_study_id_idx          (study_id),
  KEY study_pub_publication_id_idx    (publication_id)
) ENGINE=InnoDB;

/**

DRUPAL TABLES

*/

/**

@table drupal_node
@desc Contains data that will be displayed in drupal nodes.

@column drupal_id              Drupal node id (primary key, internal identifier).
@column drupal_node_id         Website drupal node id (currently).
@column autogen_text           Programmatically generated text.
@column manual_text            Manually curated text.
@column autogen_title          Programmatically generated title.
@column manual_title           Manually curated title.
@column metasum                Checksum of @autogen_txt + @manual_txt.
@column date                   Entry timestamp.
@column status                 Active (True) or retired (False) row.

*/

CREATE TABLE drupal_node (
  drupal_id             INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  drupal_node_id        INT(10) UNSIGNED UNIQUE,
  autogen_text          TEXT,
  manual_text           TEXT,
  metasum               CHAR(32),
  autogen_title         TEXT,
  manual_title          TEXT,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  status                ENUM('ACTIVE', 'RETIRED') DEFAULT 'ACTIVE',
  
  KEY drupal_id_idx             (drupal_id),
  KEY drupal_node_id_idx        (drupal_node_id)
) ENGINE=InnoDB;

CREATE TRIGGER drupal_node_md5_upd_tr BEFORE UPDATE ON drupal_node
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.drupal_node_id, NEW.autogen_text, NEW.manual_text, NEW.autogen_title, NEW.manual_title) );
CREATE TRIGGER drupal_node_md5_ins_tr BEFORE INSERT ON drupal_node
  FOR EACH ROW SET NEW.metasum = MD5( CONCAT_WS('', NEW.drupal_node_id, NEW.autogen_text, NEW.manual_text, NEW.autogen_title, NEW.manual_title) );


/**
@table drupal_node_track
@desc Links tracks to drupal_nodes.

@column drupal_node_track_id   DrupalNode-Track id (primary key, internal identifier).
@column drupal_id              Drupal_node primary id (foreign key).
@column track_id               Track table primary id (foreign key).
@column date                   Entry timestamp.

*/

CREATE TABLE drupal_node_track (
  drupal_node_track_id  INT(10) UNSIGNED NOT NULL UNIQUE AUTO_INCREMENT PRIMARY KEY,
  drupal_id             INT(10) UNSIGNED NOT NULL,
  track_id              INT(10) UNSIGNED NOT NULL,
  date                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY(drupal_id) REFERENCES drupal_node(drupal_id),
  FOREIGN KEY(track_id) REFERENCES track(track_id),
  
  KEY drupal_node_track_id_idx                 (drupal_node_track_id),
  KEY drupal_node_track_drupal_id_idx          (drupal_id),
  KEY drupal_node_track_track_id_idx           (track_id)
) ENGINE=InnoDB;


/**
 VIEWS
@header Views
@colour #DD3
*/

/**
@table sra_to_track
@desc Links all SRAs to tracks (only accessions).

@column study_id                From table study.
@column study_sra_acc	          From table study.
@column study_private_acc	      From table study.
@column experiment_id	          From table experiment.
@column experiment_sra_acc	    From table experiment.
@column experiment_private_acc	From table experiment.
@column run_id	                From table run.
@column run_sra_acc	            From table run.
@column run_private_acc	        From table run.
@column sample_id	              From table sample.
@column sample_sra_acc        	From table sample.
@column sample_private_acc	    From table sample.
@column track_id	              From table track.
@column track_status	          From table track.
@column production_name	        From table species.

*/
CREATE VIEW sra_to_track AS
  SELECT
    study_id,
    study_sra_acc,
    study_private_acc,
    experiment_id,
    experiment_sra_acc,
    experiment_private_acc,
    run_id,
    run_sra_acc,
    run_private_acc,
    sample_id,
    sample_sra_acc,
    sample_private_acc,
    sample.title AS sample_title,
    sample.description AS sample_description,
    track_id,
    track.status AS track_status,
    merge_level,
    merge_id,
    merge_text,
    production_name
  FROM
    study
    LEFT JOIN experiment USING(study_id)
    LEFT JOIN run        USING(experiment_id)
    LEFT JOIN sample     USING(sample_id)
    LEFT JOIN sra_track  USING(run_id)
    LEFT JOIN track      USING(track_id)
    LEFT JOIN taxonomy   USING(strain_id)
  ;
  
/**
@table sra_to_active_track
@desc Links all SRAs to active tracks (only accessions).

@column study_id                From table study.
@column study_sra_acc	          From table study.
@column study_private_acc	      From table study.
@column experiment_id	          From table experiment.
@column experiment_sra_acc	    From table experiment.
@column experiment_private_acc	From table experiment.
@column run_id	                From table run.
@column run_sra_acc	            From table run.
@column run_private_acc	        From table run.
@column sample_id	              From table sample.
@column sample_sra_acc        	From table sample.
@column sample_private_acc	    From table sample.
@column track_id	              From table track.
@column track_status	          From table track.
@column production_name	        From table species.

*/
CREATE VIEW sra_to_active_track AS
  SELECT *
  FROM sra_to_track
  WHERE track_status="ACTIVE"
  ;

