import htmlparser
import xmltree
import strtabs
import httpclient
import streams
import strutils
import os
import docopt

const GH = "http://github.com"
const GHS = "https://github.com"
const doc = """
Poor github cloner

Usage:
  poor clone <repository>
  poor fill <path>...
  poor (-h | --help)
  poor (-v | --version)

Options:
  -h --help     Show this screen.
  -v --version  Show version.
"""

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


let args = docopt(doc, version="Poor v0.2.0")

if args["clone"]:
  let userInput = $args["<repository>"]

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

  echo "Structure in place."

if args["fill"]:

  let arguments = args["<path>"]

  # Populate .poor files
  var poorFiles = newSeq[string]()

  for i in 0..(arguments.len - 1):
    if existsFile(arguments[i]):
      if arguments[i].endsWith(".poor"):
        poorFiles.add(arguments[i])

    elif existsDir(arguments[i]):
      for path in walkDirRec(arguments[i]):
        if path.endsWith(".poor"):
          poorFiles.add(path)

    else:
      echo arguments[i], " doesn't exist"

  let allTasks = len(poorFiles)

  if allTasks == 0:
    echo "No .poor files to fill !"
    quit(QuitFailure)
  echo "Populating ", len(poorFiles), " .poor files"

  for i, poorFile in poorFiles:
    fillPoorFile(poorFile)
    write(stdout, "\rDone ", (i + 1), "/", allTasks)
    flushFile(stdout)

  echo "\nAll done."
