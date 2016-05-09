{CompositeDisposable} = require 'atom'
$ = jQuery = require 'jquery'
# htmlparser = require 'htmlparser2'


module.exports = WebAccessibilityChecker =
  subscriptions: null
  checkingSubscriptions: {}
  regExp: {
    # Tags
    link: /(?:<a()>|<a(?=\s)([\s\S]*?[^-?])??>)/ig
    image: /(?:<img()>|<img(?=\s)([\s\S]*?[^-?])??>)/ig
    input: /(?:<input()>|<input(?=\s)([\s\S]*?[^-?])??>)/ig
    label: /(?:<label()>|<label(?=\s)([\s\S]*?[^-?])??>)/ig
    titleTag: /(?:<title()>|<title(?=\s)([\s\S]*?[^-?])??>)/ig  # /<title\s?/ig
    htmlTag: /(?:<html()>|<html(?=\s)([\s\S]*?[^-?])??>)/ig # (?:<html(?:(\s[^>]*[^-]))?>|<html()>)
    # Sections
    headSection: /<head(?:[^>]*)?>([\s\S]+?)<\/head>/ig
    # Attributes
    title: /\stitle[\s]?=/i
    id: /\sid\s?=\s?(?:"([^"]+)"|'([^']+)')/i
    alt: /\salt[\s]?=/i
    lang: /\slang[\s]?=/i
    typeHidden: /\stype\s?=\s?(?:"\s?hidden\s?"|'\s?hidden\s?')/i
    typeSubmit: /\stype\s?=\s?(?:"\s?submit\s?"|'\s?submit\s?')/i
  }
  timerArray: new Array()

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register commands
    @subscriptions.add atom.commands.add 'atom-workspace', 'web-accessibility-checker:enableContinousChecking': => @enableContinousChecking()
    @subscriptions.add atom.commands.add 'atom-workspace', 'web-accessibility-checker:checkPage': => @checkPage()
    @subscriptions.add atom.commands.add 'atom-workspace', 'web-accessibility-checker:disableContinousChecking': => @disableContinousChecking()

  deactivate: ->
    @subscriptions.dispose()
    @continousChecking.dispose()

  # =========== HELPERS ================

  tryOrRepeat: (time, action, doit) ->
   setTimeout(() ->
    if doit()
     action()
    else
     tryOrRepeat(time, action, doit)
   , time)

  getRange: (editor) ->
    # get the current position of the last curser
    cursorPosition = editor.getCursorBufferPosition()
    # Start and End Positions
    startPosition = [cursorPosition.row - 2, 0]
    endPosition = [cursorPosition.row, 1000]
    # return range
    return [startPosition, endPosition]

  scanRegExp: (editor, range, regExp) ->
    # prepare for the search
    results = []
    iterator = (result) ->
      results.push result
    # scan
    editor.scanInBufferRange(new RegExp(regExp), range, iterator)
    return results

  # =========== UI ================

  createMarker: (editor, range) ->
    # 'inside': The marker is invalidated by a change that touches the marker
    # region in any way. This is the most fragile strategy.
    options = { invalidate: 'inside', persistent: false, webAccessibilityChecker: true }
    # create marker
    marker = editor.markBufferRange(range, options)
    return marker

  deleteAllMarkers:(editor) ->
    # deleting all markers with webAccessibilityChecker parameter
    for marker in editor.findMarkers({webAccessibilityChecker: true})
      # destroy marker
      marker.destroy()

  markLineAndTooltip: (editor, marker, text) ->
    # get current date
    timestamp = (new Date()).getTime()
    # highlight the line number of the marker
    editor.decorateMarker(marker, { type: 'line-number', class: "highlight-test acc-" + timestamp })
    # init the tooltip on this created UI element - with a delay if the element needs time to be created
    setTimeout(() ->
      disposable = atom.tooltips.add($('atom-text-editor::shadow .line-number.acc-' + timestamp), {title: text, delay: { "show": 400, "hide": 200 }})
    , 250)

  markTag: (editor, marker) ->
    # highlight the marker
    editor.decorateMarker(marker, { type: 'highlight', class: "highlight-test" })

  # =========== VALIDATION ================

  scanPageTitle: (editor) ->
    # get the <head> section
    results = @scanRegExp(editor, [[0,0], [100000,100000]], @regExp.headSection)
    counter = 0

    for head in results
      # search in the section for a <title> tag
      if !head.match[1] or head.match[1].search(@regExp.titleTag) == -1
        # no <title> tag is present -> mark the start tag of the <head> section
        marker = @createMarker(editor, [
          [head.range.start.row, head.range.start.column],
          [head.range.start.row, 1000]
        ])
        @markLineAndTooltip(editor, marker, 'A <i>head</i> section should include a <i>title</i> element.')
        @markTag(editor, marker)
        counter++
    # return found issues
    return counter

  scanLanguage: (editor) ->
    # get all <html> tags
    results = @scanRegExp(editor, [[0,0], [100000,100000]], @regExp.htmlTag)
    counter = 0

    for htmlTag in results
      # attributes of the <html> tag either in index 1 or 2 of the regExp match
      if !htmlTag.match[1] and htmlTag.match[2]
        result = htmlTag.match[2]
      else
        result = htmlTag.match[1]
      # search if it has the lang attribute
      if !result or result.search(@regExp.lang) == -1
        # no lang attribute present - mark it
        marker = @createMarker(editor, htmlTag.range)
        @markLineAndTooltip(editor, marker, 'The lang attribute should be defined in the <i>html</i> tag.')
        @markTag(editor, marker)
        counter++
    # return found issues
    return counter

  scanLink: (editor, range) ->
    # get all <a> tags
    results = @scanRegExp(editor, range, @regExp.link)
    counter = 0

    for link in results
      # attributes of the <a> tag either in index 1 or 2 of the regExp match
      if !link.match[1] and link.match[2]
        result = link.match[2]
      else
        result = link.match[1]
      # search if it has the title attribute
      if result and result.search(@regExp.title) != -1
        # it has the title attribute - mark it
        marker = @createMarker(editor, link.range)
        @markLineAndTooltip(editor, marker, '<i>a</i> tags should only include a title attribute if it is not possible to make the link destination clear with the link text alone.')
        @markTag(editor, marker)
        counter++
    # return found issues
    return counter

  scanImgAlternative: (editor, range) ->
    # get all <img> tags
    results = @scanRegExp(editor, range, @regExp.image)
    counter = 0

    for image in results
      # attributes of the <img> tag either in index 1 or 2 of the regExp match
      if !image.match[1] and image.match[2]
        result = image.match[2]
      else
        result = image.match[1]
      # search if it has the alt attribute
      if !result or result.search(@regExp.alt) == -1
        # no alt attribute present - mark it
        marker = @createMarker(editor, image.range)
        @markLineAndTooltip(editor, marker, 'Each <i>img</i> tag should have an <i>alt</i> attribute which describe the image.')
        @markTag(editor, marker)
        counter++
    # return found issues
    return counter

  scanLabel: (editor, range) ->
    # get all <input> tags
    results = @scanRegExp(editor, range, @regExp.input)
    counter = 0

    for input in results
      inputChecked = false;
      issueFound = false;
      # attributes of the <input> tag either in index 1 or 2 of the regExp match
      if !input.match[1] and input.match[2]
        result = input.match[2]
      else
        result = input.match[1]
      # check if it does not have type hidden or submit
      if !result or (result.search(@regExp.typeHidden) == -1 and result.search(@regExp.typeSubmit) == -1)
        # check if it has a id attribute
        regExpId = new RegExp(@regExp.id);
        idSearchResult = regExpId.exec(result)

        if idSearchResult
          # id was found
          # value of the id attribute is either in index 1 or 2 of the regExp match
          if idSearchResult[1]
            id = idSearchResult[1]
          else
            id = idSearchResult[2]
          # get all <label> tags
          labelSearchResult = editor.getText().match(@regExp.label)

          if labelSearchResult
            # connect the attributes section of all found labels
            # and check if for="id" exists
            forLabelSearchResult = labelSearchResult.join('|').search(new RegExp('for\\s?=\\s?(?:"' + id + '"|\'' + id + '\')', 'ig'));
            if forLabelSearchResult == -1
              # does not contain for = "id"
            else
              # for = "id" was found -> no issue
              inputChecked = true

        if !inputChecked
          # check if the <input> is covered from a label tag
          # index of the label
          indexInput = input.match.index
          # index of the closest </label> tag before the <input>
          indexEndLabelsBefore = editor.getText().substring(0,indexInput).toLowerCase().lastIndexOf('</label')
          # index of the closest <label> tag before the <input>
          indexStartLabelsBefore = editor.getText().substring(0,indexInput).toLowerCase().lastIndexOf('<label')
          # if a open <label> tag is found and closer then a closed on
          if indexStartLabelsBefore > -1 and indexEndLabelsBefore < indexStartLabelsBefore
            # ok
          else
            # no -> issue
            issueFound = true;

        if issueFound
          # mark it
          marker = @createMarker(editor, input.range)
          @markLineAndTooltip(editor, marker, 'Each <i>input</i> tag should have a <i>label</i> tag, where the for attribute match the id attribute of the <i>input</i> tag<br>OR the <i>label</i> tag covers the <i>input</i> tag and the description.')
          @markTag(editor, marker)
          counter++
    # return found issues
    return counter

  # =========== USER FUNCTIONS ================

  checkIssues: (editor, range, feedback)->
    # start messuring time
    tmpTimer = window.performance.now();
    # check all web accessibility rules
    pageTitleIssues = @scanPageTitle(editor)
    imgAlternativeIssues = @scanImgAlternative(editor, range)
    labelIssues = @scanLabel(editor, range)
    LanguageIssues = @scanLanguage(editor)
    LinkIssues = @scanLink(editor, range)
    # stop time and print it
    @timerArray[0] = window.performance.now() - tmpTimer
    console.log @timerArray
    # if an overview of the found issues should be displayed
    if feedback
      # create a notification
      message = "<b>Web accessibility issues:</b><br>" +
                "<b>" + pageTitleIssues + "</b> issue related to the page title was found.<br>" +
                "<b>" + imgAlternativeIssues + "</b> issue related to an image was found.<br>" +
                "<b>" + labelIssues + "</b> issue related to an input was found.<br>" +
                "<b>" + LanguageIssues + "</b> issue related to the page language was found.<br>" +
                "<b>" + LinkIssues + "</b> issue related to a link was found."
      atom.notifications.addInfo(message)

  checkPage: ->
    editor = atom.workspace.getActiveTextEditor()
    # delete all markers
    @deleteAllMarkers(editor)
    # check the whole page for web accessibility issues
    range = [[0,0], [100000,100000]];
    @checkIssues(editor, range, true)

  ContinousChecking: (changeEvents) ->
    editor = atom.workspace.getActiveTextEditor()
    # delete all markers
    WebAccessibilityChecker.deleteAllMarkers(editor)
    # check the whole page for web accessibility issues
    range = [[0,0], [100000,100000]];
    WebAccessibilityChecker.checkIssues(editor, range, false)

  enableContinousChecking: ->
    editor = atom.workspace.getActiveTextEditor()
    # if not already activated for this editor
    if !@checkingSubscriptions[editor.id]
      # check whole page
      @checkPage()
      # make a new subscription and set onDidStopChanging function, which get
      # triggered 300ms after the user has stopped making changes
      @checkingSubscriptions[editor.id] = new CompositeDisposable
      @checkingSubscriptions[editor.id].add onChanging = editor.onDidStopChanging(WebAccessibilityChecker.ContinousChecking)
      # notify the user
      atom.notifications.addInfo("Continous Checking is enabled!")
    else
      # notify the user
      atom.notifications.addInfo("Continous Checking was already enabled!")

  disableContinousChecking: ->
    editor = atom.workspace.getActiveTextEditor()
    # if activated for this editor
    if @checkingSubscriptions[editor.id]
      # dispose the subscription
      @checkingSubscriptions[editor.id].dispose()
      # delete the object entry
      delete @checkingSubscriptions[editor.id]
      # notify the user
      atom.notifications.addInfo("Continous Checking is disabled!")
    else
      # notify the user
      atom.notifications.addInfo("Continous Checking was already disabled!")

  # =========== TESTING - NOT USED ================

  deleteMarkersInRange: (startRow, endRow) ->
    # console.log 'deleting markers in area'

    for marker in @markerLayer.getMarkers()
      range = marker.bufferMarker.getRange()
      if not (range.end.row < startRow || range.start.row > endRow)
        # console.log 'marker destroyed'
        marker.destroy()

  getChangedRange: (changeEvents) ->
    console.log "Number of cursors: #{changeEvents.changes.length}"
    # for each of the cursors
    changes = [];
    for cursor in changeEvents.changes
      insertText = false
      replacedText = false
      deleteText = false

      #each cursor's 'newText' holds any new text that was added or an empty string if this is a delete
      #if this is an insert
      if cursor.newText.length > 0
        # record where the new text is being inserted
        # get the starting position of the insert
        insertText = true
        startingRow = cursor.start.row
        startingColumn = cursor.start.column
        startingColumn = 0

        #newExtent.row is the number of rows that have been added for this insert (0 if the insert all happened on the same line)
        #newExtent.column is the number of columns moved to the right (or characters added) for this insert if the insert happened on the same line (newExtent.row is 0)
        #newExtent.column is the ending column number after the insert if this was a multiline insert (newExtent.row is > 0)

        #get the number of rows moved and add to the starting row for the ending row number
        endingRow = cursor.start.row + cursor.newExtent.row

        #if the insert happened all on a single line
        if cursor.newExtent.row is 0
          #add the starting column to the number of characters added to get where the insert ends
          endingColumn = cursor.start.column + cursor.newExtent.column

        else #multiline insert
          #this is the column where the insert ends on the new line
          endingColumn = cursor.newExtent.column

        endingColumn = 100000;

        #the cursor's 'oldExtent' tells us if any text was selected and is being replace in this insert
        if cursor.oldExtent.row > 0 or cursor.oldExtent.column > 0

            #some text is being removed and replaced with the new text
            replacedText = true

            #the starting position of the text being removed
            removedTextStartRow = cursor.start.row
            removedTextStartColumn = cursor.start.column
            removedTextStartColumn = 0

            #the end row is the sum of the start row and the number of additional rows selected
            removedTextEndRow = cursor.start.row + cursor.oldExtent.row

            #if the selected text was on a single line
            if cursor.oldExtent.row is 0
              #the end column is the start column plus the number of characters selected
              removedTextEndColumn = cursor.start.column + cursor.oldExtent.column
              removedTextEndColumn = 0

            else #multiple lines selected
              #in a multiline selected text the end column is the old extent column Number
              removedTextEndColumn = cursor.oldExtent.column
              removedTextEndColumn = 0

            removedTextEndColumn = 10000;

        #if there was some text replaced, log it
        if replacedText
            console.log "Replacing some text from row: #{removedTextStartRow} col: #{removedTextStartColumn} to row: #{removedTextEndRow} col: #{removedTextEndColumn}"

        #log what was inserted
        console.log "Inserted #{cursor.newText.length} characters (#{cursor.newText}) starting at position row: #{startingRow} col: #{startingColumn} and ending at row: #{endingRow} col: #{endingColumn}"

      else #nothing in the cursor's 'newText', it is a delete

        #get the starting position of the delete
        deleteText = true
        startingRow = cursor.start.row
        startingColumn = cursor.start.column
        startingColumn = 0;

        #get the number of rows removed and add to the starting row for the ending row number
        endingRow = cursor.start.row + cursor.oldExtent.row

        #if the delete happened all on a single line
        if cursor.oldExtent.row is 0
          #add the starting column to the number of characters deleted to get where the delete ends
          endingColumn = cursor.start.column + cursor.oldExtent.column

        else #multiline delete
          #this is the column where the delete ends on the new line
          endingColumn = cursor.oldExtent.column

        endingColumn = 10000;
        #the cursor's newExtent is not used in deletes

        #log what was deleted
        console.log "Deleted text starting at position row: #{startingRow} col: #{startingColumn} and ending at row: #{endingRow} col: #{endingColumn}"

      if !deleteText
        rangeStart = [startingRow, 0]
        rangeEnd = [endingRow, 100000]

      else
        rangeStart = [startingRow, 0]
        rangeEnd = [endingRow, 100000]

      changes.push([rangeStart, rangeEnd]);

    return changes;
