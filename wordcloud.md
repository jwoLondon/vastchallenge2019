---
id: litvis
follows: dataAndConfig
---

@import "css/vastChallenge.less"

# Wordclouds

## Data Shaping

To generate a text file containing only message text without enclosing (or internal) quotation marks and with reYInt headers removed:

```bash
tail -n +2 YInt.csv | \
cut -d ',' -f 4-99 | \
sed 's/[\\\"]//g;s/re: //g;s/&quot;//g' | awk '{ print "\""$0"\","}' | \
awk 'length($0)>3' \
> messages.txt
```

_(remove the first header line; select the columns containing the message; remove any backslashes, quotation marks, `re:` and HTML escaped `&quot;`; place each line in quotation marks and add a comma to the end; filter messages at least three characters long)_

To build a list of word frequencies, from which we can identify a list of stopwords and irrelevant terms:

```bash
tr ' ' '\n' < messages.txt | \
tr A-Z a-z | \
sed 's/[\".,!?:]//g' | \
sort | uniq -c | sort -rn | \
awk '{print $2","$1}'
```

Stopwords, taken from https://gist.github.com/sebleier/554280#gistcomment-2838837 were removed and additional mispelled stopwords were selected from the ordered list of most frequent words in messages, where those words occurred at least 30 times. Filtering was implemented in a CLI call to a custom Elm program via node.

For temporal analysis, messages are grouped in to 3 hour periods (Mon 00:00-02:59, Mon 03:00-05:59 etc.) and then word frequency lists generated as above with a column storing the date/time period (in a single bash script):

```bash
#!/bin/bash

# File to store single list of word frequencties
echo 'word,freq,timeblock' > temp.txt

for f in yint*.csv
do
  echo "Processing $f file..."

  # Word day to numeric date translation (e.g Mon -> 06, Tue ->07 etc.)
  d=${f:4:3}
  if [ $d == 'Mon' ]
  then
  dt='06'
  elif [ $d == 'Tue' ]
  then
  dt='07'
  elif [ $d == 'Wed' ]
  then
  dt='08'
  elif [ $d == 'Thu' ]
  then
  dt='09'
  elif [ $d == 'Fri' ]
  then
  dt='10'
  fi

  # Generate an array of cleaned messages for each time period
  echo '[' > messages${f:4:6}txt
  tail -n +2 $f | cut -d ',' -f 4-99 | sed 's/[\\\"]//g;s/re: //g;s/&quot;//g' | awk '{ print "\""$0"\","}' | awk 'length($0)>3' | sed '$ s/.$//' >> messages${f:4:6}txt
  echo ']' >> messages${f:4:6}txt

  # Generate an ordered list of word frequencies for each time period
  tr ' ' '\n' < messages${f:4:6}txt |tr A-Z a-z | sed 's/[\".,!?:]//g' | sort | uniq -c | sort -rn | awk -v tb="2020-04-"$dt" "${f:7:2}":00:00" '{print $2","$1","tb}' >> temp.txt
done

# Filter out stopwords and mispelled variants
node ../../otherCode/fileProcessor/fileProcessor.js temp.txt wordFreqsAll.csv

# We no longer need the temporary file of unfiltered word frequencies.
rm temp.txt
```

```elm {l}
wordcloud : String -> V.Spec
wordcloud fName =
    let
        toSWFormat : List String -> V.Str
        toSWFormat sws =
            "(" :: List.intersperse "|" sws ++ [ ")" ] |> String.concat |> V.str

        ds =
            V.dataSource
                [ V.data "table" [ V.daUrl (V.str (dataPath ++ fName)) ]
                    |> V.transform
                        [ V.trCountPattern (V.field "data")
                            [ V.cpCase V.lowercase
                            , V.cpPattern (V.str "[\\w']{3,}")
                            , V.cpStopwords (toSWFormat (stopWords ++ misspellStopWords))
                            ]
                        , V.trFormulaInitOnly "[-45, 0, 45][~~(random() * 3)]" "angle"
                        ]
                ]

        sc =
            V.scales
                << V.scale "cScale"
                    [ V.scType V.scOrdinal
                    , V.scRange (V.raStrs [ "#d5a928", "#652c90", "#939597" ])
                    ]

        mk =
            V.marks
                << V.mark V.text
                    [ V.mFrom [ V.srData (V.str "table") ]
                    , V.mEncode
                        [ V.enEnter
                            [ V.maText [ V.vField (V.field "text") ]
                            , V.maAlign [ V.hCenter ]
                            , V.maDir [ V.textDirectionValue V.tdLeftToRight ]
                            , V.maBaseline [ V.vAlphabetic ]
                            , V.maFill [ V.vScale "cScale", V.vField (V.field "text") ]
                            ]
                        ]
                    , V.mTransform
                        [ V.trWordcloud
                            [ V.wcSize (V.nums [ 400, 800 ])
                            , V.wcText (V.field "text")
                            , V.wcRotate (V.numExpr (V.exField "datum.angle"))
                            , V.wcFont (V.str "Roboto Condensed")
                            , V.wcFontSize (V.numExpr (V.exField "datum.count"))
                            , V.wcFontSizeRange (V.nums [ 6, 100 ])
                            , V.wcPadding (V.num 2)
                            ]
                        ]
                    ]
    in
    V.toVega
        [ V.width 400, V.height 400, V.padding 5, ds, sc [], mk [] ]
```

### Wed

06:00
^^^elm {v=(wordcloud "messagesWed06.txt") }^^^
09:00
^^^elm {v=(wordcloud "messagesWed09.txt")}^^^
12:00
^^^elm {v=(wordcloud "messagesWed12.txt")}^^^
15:00
^^^elm {v=(wordcloud "messagesWed15.txt")}^^^
18:00
^^^elm {v=(wordcloud "messagesWed18.txt")}^^^
21:00
^^^elm {v=(wordcloud "messagesWed21.txt")}^^^

#### Thu

00:00
^^^elm {v=(wordcloud "messagesThu00.txt")}^^^
03:0
^^^elm {v=(wordcloud "messagesThu03.txt")}^^^
06:00
^^^elm {v=(wordcloud "messagesThu06.txt")}^^^
09:00
^^^elm {v=(wordcloud "messagesThu09.txt")}^^^
12:00
^^^elm {v=(wordcloud "messagesThu12.txt")}^^^
15:00
^^^elm {v=(wordcloud "messagesThu15.txt")}^^^

```elm {l=hidden}
stopWords : List String
stopWords =
    --Stopword list from <https://gist.github.com/sebleier/554280#gistcomment-2838837>
    -- Removed the following disaster-related words:
    -- affected, approximately, cause, causes, help, home, immediate, immediately, information, importance, important, line, need, needs, poorly,
    -- million, thousand, hundred, nine, ninety, eight, eighty, seven, six, five, four, three, two.
    [ "a", "about", "above", "after", "again", "against", "ain", "all", "am", "an", "and", "any", "are", "aren", "aren't", "as", "at", "be", "because", "been", "before", "being", "below", "between", "both", "but", "by", "can", "couldn", "couldn't", "d", "did", "didn", "didn't", "do", "does", "doesn", "doesn't", "doing", "don", "don't", "down", "during", "each", "few", "for", "from", "further", "had", "hadn", "hadn't", "has", "hasn", "hasn't", "have", "haven", "haven't", "having", "he", "her", "here", "hers", "herself", "him", "himself", "his", "how", "i", "if", "in", "into", "is", "isn", "isn't", "it", "it's", "its", "itself", "just", "ll", "m", "ma", "me", "mightn", "mightn't", "more", "most", "mustn", "mustn't", "my", "myself", "needn", "needn't", "no", "nor", "not", "now", "o", "of", "off", "on", "once", "only", "or", "other", "our", "ours", "ourselves", "out", "over", "own", "re", "s", "same", "shan", "shan't", "she", "she's", "should", "should've", "shouldn", "shouldn't", "so", "some", "such", "t", "than", "that", "that'll", "the", "their", "theirs", "them", "themselves", "then", "there", "these", "they", "this", "those", "through", "to", "too", "under", "until", "up", "ve", "very", "was", "wasn", "wasn't", "we", "were", "weren", "weren't", "what", "when", "where", "which", "while", "who", "whom", "why", "will", "with", "won", "won't", "wouldn", "wouldn't", "y", "you", "you'd", "you'll", "you're", "you've", "your", "yours", "yourself", "yourselves", "could", "he'd", "he'll", "he's", "here's", "how's", "i'd", "i'll", "i'm", "i've", "let's", "ought", "she'd", "she'll", "that's", "there's", "they'd", "they'll", "they're", "they've", "we'd", "we'll", "we're", "we've", "what's", "when's", "where's", "who's", "why's", "would", "able", "abst", "accordance", "according", "accordingly", "across", "act", "actually", "added", "adj", "affecting", "affects", "afterwards", "ah", "almost", "alone", "along", "already", "also", "although", "always", "among", "amongst", "announce", "another", "anybody", "anyhow", "anymore", "anyone", "anything", "anyway", "anyways", "anywhere", "apparently", "arent", "arise", "around", "aside", "ask", "asking", "auth", "available", "away", "awfully", "b", "back", "became", "become", "becomes", "becoming", "beforehand", "begin", "beginning", "beginnings", "begins", "behind", "believe", "beside", "besides", "beyond", "biol", "brief", "briefly", "c", "ca", "came", "cannot", "can't", "certain", "certainly", "co", "com", "come", "comes", "contain", "containing", "contains", "couldnt", "date", "different", "done", "downwards", "due", "e", "ed", "edu", "effect", "eg", "either", "else", "elsewhere", "end", "ending", "enough", "especially", "et", "etc", "even", "ever", "every", "everybody", "everyone", "everything", "everywhere", "ex", "except", "f", "far", "ff", "fifth", "first", "fix", "followed", "following", "follows", "former", "formerly", "forth", "found", "furthermore", "g", "gave", "get", "gets", "getting", "give", "given", "gives", "giving", "go", "goes", "gone", "got", "gotten", "h", "happens", "hardly", "hed", "hence", "hereafter", "hereby", "herein", "heres", "hereupon", "hes", "hi", "hid", "hither", "howbeit", "however", "id", "ie", "im", "inc", "indeed", "index", "instead", "invention", "inward", "itd", "it'll", "j", "k", "keep", "keeps", "kept", "kg", "km", "know", "known", "knows", "l", "largely", "last", "lately", "later", "latter", "latterly", "least", "less", "lest", "let", "lets", "like", "liked", "likely", "little", "'ll", "look", "looking", "looks", "ltd", "made", "mainly", "make", "makes", "many", "may", "maybe", "mean", "means", "meantime", "meanwhile", "merely", "mg", "might", "miss", "ml", "moreover", "mostly", "mr", "mrs", "much", "mug", "must", "n", "na", "name", "namely", "nay", "nd", "near", "nearly", "necessarily", "necessary", "neither", "never", "nevertheless", "new", "next", "nobody", "non", "none", "nonetheless", "noone", "normally", "nos", "noted", "nothing", "nowhere", "obtain", "obtained", "obviously", "often", "oh", "ok", "okay", "old", "omitted", "one", "ones", "onto", "ord", "others", "otherwise", "outside", "overall", "owing", "p", "page", "pages", "part", "particular", "particularly", "past", "per", "perhaps", "placed", "please", "plus", "possible", "possibly", "potentially", "pp", "predominantly", "present", "previously", "primarily", "probably", "promptly", "proud", "provides", "put", "q", "que", "quickly", "quite", "qv", "r", "ran", "rather", "rd", "readily", "really", "recent", "recently", "ref", "refs", "regarding", "regardless", "regards", "related", "relatively", "research", "respectively", "resulted", "resulting", "results", "right", "run", "said", "saw", "say", "saying", "says", "sec", "section", "see", "seeing", "seem", "seemed", "seeming", "seems", "seen", "self", "selves", "sent", "several", "shall", "shed", "shes", "show", "showed", "shown", "showns", "shows", "significant", "significantly", "similar", "similarly", "since", "slightly", "somebody", "somehow", "someone", "somethan", "something", "sometime", "sometimes", "somewhat", "somewhere", "soon", "sorry", "specifically", "specified", "specify", "specifying", "still", "stop", "strongly", "sub", "substantially", "successfully", "sufficiently", "suggest", "sup", "sure", "take", "taken", "taking", "tell", "tends", "th", "thank", "thanks", "thanx", "thats", "that've", "thence", "thereafter", "thereby", "thered", "therefore", "therein", "there'll", "thereof", "therere", "theres", "thereto", "thereupon", "there've", "theyd", "theyre", "think", "thou", "though", "thoughh", "throug", "throughout", "thru", "thus", "til", "tip", "together", "took", "toward", "towards", "tried", "tries", "truly", "try", "trying", "ts", "twice", "u", "un", "unfortunately", "unless", "unlike", "unlikely", "unto", "upon", "ups", "us", "use", "used", "useful", "usefully", "usefulness", "uses", "using", "usually", "v", "value", "various", "'ve", "via", "viz", "vol", "vols", "vs", "w", "want", "wants", "wasnt", "way", "wed", "welcome", "went", "werent", "whatever", "what'll", "whats", "whence", "whenever", "whereafter", "whereas", "whereby", "wherein", "wheres", "whereupon", "wherever", "whether", "whim", "whither", "whod", "whoever", "whole", "who'll", "whomever", "whos", "whose", "widely", "willing", "wish", "within", "without", "wont", "words", "world", "wouldnt", "www", "x", "yes", "yet", "youd", "youre", "z", "zero", "a's", "ain't", "allow", "allows", "apart", "appear", "appreciate", "appropriate", "associated", "best", "better", "c'mon", "c's", "cant", "changes", "clearly", "concerning", "consequently", "consider", "considering", "corresponding", "course", "currently", "definitely", "described", "despite", "entirely", "exactly", "example", "going", "greetings", "hello", "hopefully", "ignored", "inasmuch", "indicate", "indicated", "indicates", "inner", "insofar", "it'd", "keep", "keeps", "novel", "presumably", "reasonably", "second", "secondly", "sensible", "serious", "seriously", "sure", "t's", "third", "thorough", "thoroughly", "well", "wonder" ]


misspellStopWords : List String
misspellStopWords =
    --Words that are mispelled or extra stops and likely to be stopwords if spelled
    -- correctly  and occur at least 30 times in the full list of messages.
    [ "iím", "tjehe", "yuo", "tehhe", "thgehe", "tghehe", "donít", "tjhehe", "itís", "yeah", "dont", "anddnd", "^ag", "anbdnd", "canít", "ytouou", "youíre", "tyhehey", "soamkeeone", "weíre", "tr", "someneomething", "anytyingnything", "weasas", "liukeike", "teho", "itaht", "thtao", "thgeo", "adn", "teh", "&gt;", "xo", "&amp;", "thadnn", "doo", "ive", "theyíre", "eh", "doesnt", "tjeo", "yuor", "um", "thgathathgat", "ya", "uisese", "ithge", "thatís", "tyheo", "jstuust", "anddre", "anytyhehing", "whereís", "tjheo", "thtahathta", "ur", "tehyhey", "tgheo", "tahthataht", "itghe", "shoudlhould", "hteyhe", "&quot;one", "xoxo", "weíll", "atje", "wehnhen", "noh", "it&quot;", "abotubout", "--", "lik", "iteh", "tahtook", "tahthe", "syasaysyas", "jsutust", "&quot;the", "tghehey", "peje", "tjhehatjhe", "itso", "ithta", "htishis", "duh", "cadnn", "thadnt", "hadnve", "adnn", "you-you", "wooo", "thtaoo", "hesomeone", "hadns", "yeadnrs", "adnlwadnys", "-_-", "yup", "wsheit", "wehnould", "tu", "thn", "jes", "anddt", "tyhehe", "thoguht", "happenedas", "gotta", "gonna", "including", "syjhe", "one's", "hehhee", "thing", "things", "yuoou", "sooo", "eee", "aswell" ]
```
