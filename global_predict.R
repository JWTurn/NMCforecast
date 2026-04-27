# forecasting model
repos <- c("https://predictiveecology.r-universe.dev", getOption("repos"))
source("https://raw.githubusercontent.com/PredictiveEcology/pemisc/refs/heads/development/R/getOrUpdatePkg.R")
getOrUpdatePkg(c("Require", "SpaDES.project"), c("1.0.1.9024", "1.0.1.9000")) # only install/update if required
#Require::Install("PredictiveEcology/SpaDES.core@development")
#Require::Install("PredictiveEcology/reproducible@development")

projPath = "~/git-local/NMCforecast"
reproducibleInputsPath = "~/git-local/reproducibleInputs"

out <- SpaDES.project::setupProject(
  Restart = TRUE,
  useGit = 'JWTurn',
  updateRprofile = TRUE,
  #overwrite = TRUE,
  paths = list(projectPath =  projPath
               #"packagePath" = file.path("packages", Require:::versionMajorMinor())
  ),
  options = options(spades.allowInitDuringSimInit = TRUE,
                    spades.allowSequentialCaching = TRUE,
                    spades.moduleCodeChecks = FALSE,
                    spades.recoveryMode = 1,
                    reproducible.inputPaths = reproducibleInputsPath,
                    reproducible.useMemoise = TRUE
                    ,reproducible.cloudFolderID = 'https://drive.google.com/drive/folders/1lDVP0G1FFft5WJgnKBLPPlkTXPsU04hr?usp=share_link'
  ),
  modules = c(
    "PredictiveEcology/Biomass_borealDataPrep@development",
    "PredictiveEcology/Biomass_core@development",
    "PredictiveEcology/Biomass_regeneration@master",
    file.path("PredictiveEcology/scfm@development/modules",
              c("scfmDataPrep",
                "scfmIgnition", "scfmEscape", "scfmSpread",
                "scfmDiagnostics")),
    "JWTurn/caribou_SSUD@addYukon"
  ),
  params = list(
    .globals = list(
      .plots = c("png"),
      .studyAreaName=  "NMCsimp",
      #jurisdiction = c("NMC"),
      outputFolderID = 'https://drive.google.com/drive/folders/1E46xkqApeXGJy5x8_mwu7z7RgZmkNN88?usp=share_link',
      .useCache = c(".inputObjects"),
      modelScale = "global",
      dataYear = 2020,
      sppEquivCol = "LandR",
      normalizePDE = TRUE,
      ecotype = 'northern_mountain'

    ),
    scfmDataPrep = list(
      targetN = 3000,
      .useParallelFireRegimePolys = TRUE
    ),

    caribou_SSUD = list(
      simulationProcess = "dynamic",
      simulationScale = "global"
    )
  ),

  packages = c('RCurl', 'XML', 'snow', 'googledrive', 'httr2', "terra", "gert", "remotes",
               "PredictiveEcology/reproducible@development", "PredictiveEcology/LandR@development",
               "PredictiveEcology/SpaDES.core@development"),

  #studyAreaReporting = ,

  times = list(start = 2020, end = 2075),

  studyAreaLarge = reproducible::prepInputs(url = 'https://drive.google.com/file/d/1gW6DBurw2uBx5cAZLcmWd6qBD7eMEd-4/view?usp=share_link',
                                            fun = 'terra::vect',
                                            destinationPath = 'inputs') |>
                    terra::project("EPSG:3978"),

  studyArea = studyAreaLarge,

  studyAreaCalibration = studyAreaLarge,

  modelLand = reproducible::prepInputs(url = 'https://drive.google.com/file/d/1EJ9QX-61YkL4X26RggNNw_xofzJnbbWm/view?usp=share_link',
                                       fun = 'terra::rast',
                                       destinationPath = 'outputs')  |>
    terra::project("EPSG:3978")|>
    reproducible::Cache(),


  rasterToMatchLarge = {
    rtml <- modelLand[[1]]
    rtml[] <- 1
    #rtml[] <- 1
    terra::mask(rtml, studyAreaLarge)
  },

  rasterToMatch_SSUD = rasterToMatchLarge,

  rasterToMatch = {
    reproducible::postProcess(rasterToMatchLarge, cropTo = studyAreaLarge, maskTo = studyAreaLarge)
  },

  rasterToMatchCoarse = {
    terra::aggregate(rasterToMatch, 2)
  },

  rasterToMatchCalibration = rasterToMatchLarge,

  ## scfm workaround retained
  treedFirePixelTableSinceLastDisp = data.table::data.table(
    pixelIndex = integer(), pixelGroup = integer(), burnTime = numeric()
  ),

  sppEquiv = {
    speciesInStudy <- LandR::speciesInStudyArea(studyAreaLarge, dPath = paths$inputPath)
    species <- LandR::equivalentName(speciesInStudy$speciesList, df = LandR::sppEquivalencies_CA, "LandR")
    sppEquiv <- LandR::sppEquivalencies_CA[LandR %in% species]
    sppEquiv <- sppEquiv[KNN != "" & LANDIS_traits != ""]
    sppEquiv
  },

  iSSAmodels = reproducible::prepInputs(url = 'https://drive.google.com/file/d/1O_2_pP-9ZRqNqFxief1TIAcjDGdJTAfW/view?usp=share_link',
                                    fun = 'readRDS',
                                    destinationPath = 'outputs') |>
    reproducible::Cache(),


  studyAreaCaribou = {
    sa <- reproducible::prepInputs(url = 'https://drive.google.com/file/d/11nFGKHw36Dtxjd5xS-nExuziOB26VRoK/view?usp=share_link',
                                   fun = 'terra::vect',
                                   destinationPath = 'inputs') |>
          terra::project("EPSG:3978")
    terra::fillHoles(sa, inverse = F)}
  ,

  studyArea_juris = list(NMC = studyAreaLarge),
  # reproducible::prepInputs(url = 'https://drive.google.com/file/d/1KcJ9oPTEsWYZAX4rHi2p84y0LjLhjtvJ/view?usp=share_link',
  #                                          fun = 'readRDS',
  #                                          destinationPath = 'outputs')

  # OUTPUTS TO SAVE -----------------------
  outputs = {
    # save to disk objects, specified years

    rbind(
      data.frame(
        objectName = rep('pde', 1),
        saveTime = c(2020),
        fun = rep("saveRDS", 1),
        file = paste0(rep('pde', 1), rep(".RDS", 1))
        ,
        package = rep("base", 1)
      ),
      data.frame(
        objectName = rep('pdeMap', 1),
        saveTime = c(2020),
        fun = rep("saveRDS", 1),
        file = paste0(rep('pdeMap', 1), rep(".RDS", 1))
        ,
        package = rep("base", 1)
      ),
      data.frame(
        objectName = rep('simPde', 12),
        saveTime = append(2022, seq(from = 2025, to = 2075, by = 5)),
        fun = rep("saveRDS", 12),
        file = paste0(rep('pde', 12), rep(".RDS", 12))
        ,
        package = rep("base", 12)
      ),
      data.frame(
        objectName = rep('simPdeMap', 12),
        saveTime = append(2022, seq(from = 2025, to = 2075, by = 5)),
        fun = rep("saveRDS", 12),
        file = paste0(rep('pdeMap', 12), rep(".RDS", 12))
        ,
        package = rep("base", 12)
      )
      #,

      # data.frame(
      #   objectName = rep('timeSinceFire', 12),
      #   saveTime = seq(from = 2025, to = 2075, by = 5),
      #   fun = rep("writeRaster", 12),
      #   file = paste0(rep('timeSinceFire', 12), rep(".tif", 12)),
      #   package = rep("terra", 12)
      # )
    )
  }

)


results <- SpaDES.core::simInitAndSpades2(out)
results <- SpaDES.core::restartSpades()
saveRDS(results, file.path('outputs', 'forecastSpaDESout.rds'))
