import htmlparser
import xmltree
import strtabs
import httpclient
import streams
import strutils
import progress, os

const GH = "http://github.com"
const GHS = "https://github.com"

proc cloneUrl(url: string, parent: string) =
  ## Poor clone a url in given parent directory
  let pageStream = newStringStream(getContent(url))
  let tree = parseHTML(pageStream)

  for link in tree.findAll("a"):
    try:
      let class = link.attrs["class"]
      # Very basic check
      if class == "js-navigation-open":
        let href = link.attrs["href"]

        if contains(href, "/tree/master/"):
          # This is another directory
          try:
            # Check for parent jump and pass it on
            discard link.attrs["rel"]
          except:
            cloneUrl(joinPath([GHS, href]), parent)
        else:
          # This is a file
          let file = split(href, "/blob/master/")[1]
          var (dir, filename, ext) = splitFile(file)
          dir = joinPath(["./", parent, dir])
          filename = join([filename, ext, ".poor"])
          # Create directory and file with raw url
          if not existsDir(dir):
            createDir(dir)
          var rawUrl = joinPath([GHS, href])
          writeFile(joinPath([dir, filename]),
                    rawUrl.replace("/blob/master/", "/raw/master/"))
    except:
      continue

proc fillPoorFile(poorfile: string) =
  ## Download data in .poor file
  let url = readFile(poorfile)
  downloadFile(url, poorfile.replace(".poor", ""))
  removeFile(poorfile)

proc help() =
  ## Print help
  echo "Poor gets the file tree of given github repository and lets you do selective download."
  echo "Saves bandwidth (though wastes time).\n"
  echo "Usage:"
  echo "\tpoor <github_user>/<repo> : for generating file structure"
  echo "\tpoor : for downloading files"

if paramCount() == 0:
  # Populate .poor files
  var poorFiles = newSeq[string]()

  for path in walkDirRec("./"):
    if path.endsWith(".poor"):
      poorFiles.add(path)

  if len(poorFiles) == 0:
    echo "No .poor files found !"
    echo "Run poor --help for help"
    quit(QuitFailure)
  echo "Populating ", len(poorFiles), " .poor files"

  let bar = newProgressBar(total=len(poorFiles))

  bar.start()
  for poorFile in poorFiles:
    fillPoorFile(poorFile)
    bar.increment()
  bar.finish()
  echo "\nAll done."

elif paramCount() == 1:
  # Poor clone a repository
  let userInput = paramStr(1)

  if (userInput == "--help") or
     (userInput == "-h"):
    help()
    quit()

  var repoUrl = ""
  if userInput.startsWith(GHS) or
     userInput.startsWith(GH):
    repoUrl = userInput
  else:
    repoUrl = joinPath([GHS, userInput])

  if repoUrl.endsWith("/"):
    repoUrl.removeSuffix("/")

  let repoUrlSplit = split(repoUrl, "/")
  let repoName = repoUrlSplit[repoUrlSplit.high]

  echo "Poor cloning ", repoUrl, " in ", repoName
  echo "Generating directory structure..."

  cloneUrl(repoUrl, repoName)

  echo "Structure in place. Remove unwanted files and run <poor> inside the directory to get data."

else:
  help()
