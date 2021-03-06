''
' Base class for instantiating DOM nodes
' @param - String - The type of node to instantiate
' @return - Object - A new node
''
function newNode( nodeType ) as Object
	node = createObject( "roAssociativeArray" )
	node.nodeType = nodeType
	return node
end function


''
' Instantiate a text node
' @param - String - The text for the node to contain
' @return - Object - A new text node
''
function newTextNode( text ) as Object
	node = newNode( "text" )
	node.text = text.trim()
	return node
end function


''
' Instantiate a new hyperlink node
' @param - String - The text for the node to contain
' @param - String - The URL for the node to link to
' @return - Object - A new hyperlink node
''
function newLinkNode( text, url ) as Object
	node = newNode( "link" )
	node.text = text.trim()
	node.url = url
	return node
end function


''
' Instantiate a new node for displaying a line of whitespace
' @return - Object - A new newline node
''
function newNewlineNode() as Object
	return newNode( "newline" )
end function


''
' Instantiate a new node for signifying the end of file has been reached
' @return - Object - A new EOF node
''
function newEOFNode() as Object
	return newNode( "EOF" )
end function


''
' Strip out all extraneous tags, sections, scripts, etc. from a raw HTML string
' @param - String - Raw HTML page body
' @return - String - Cleaned HTML page body
''
function getCleanBody( text ) as String

	'Get just the stuff in <body> tags
	bodyRegex = createObject( "roRegex", "<body.*?</body>", "is" )
	body = bodyRegex.match( text )
	if body.count() = 0
		return ""
	end if
	text = body[0]

	'Strip out script and style blocks
	scriptsRegex = createObject( "roRegex", "<((script)|(style)).*?</((script)|(style))>", "is" )
	text = scriptsRegex.replaceAll( text, "" )

	'Insert characters to delimit newlines at div and h1-3 tags
	newlineRegex = createObject( "roRegex", "<((div)|(h[1-3]))[^>]*>", "is" )
	text = newlineRegex.replaceAll( text, "^" )

	'Strip out html entities
	entitiesRegex = createObject( "roRegex", "&[^;]+;", "i" )
	text = entitiesRegex.replaceAll( text, "" )

	'Remove any remaining html tags
	junkTagsRegex = createObject( "roRegex", "<(?!\/?a(?=>|\s.*>))\/?.*?>", "is" )
	return junkTagsRegex.replaceAll( text, "" )
end function


''
' Instantiate a Lexer object suitable for making tokens out of raw HTML
' @param - String - Cleaned HTML body
' @return - Object - new Lexer object
''
function newLexer( stream ) as Object
	lexer = createObject( "roAssociativeArray" )
	rawStream = getCleanBody( stream )
	lexer.stream = rawStream
	lexer.streamLength = lexer.stream.len()
	lexer.position = 0
	lexer.tokens = []
	lexer.getToken = lexerGetToken
	lexer.getTokenAt = lexerGetTokenAt
	lexer.aRegex = createObject( "roRegex", "<a.*?</a>", "is" )

	return lexer
end function


''
' Get the next token from Lexers internal pointer
' @return - Object - Node
''
function lexerGetToken() as Object

	workingString = ""

	if m.position >= m.streamLength
		return newEOFNode()
	end if

	for i = m.position to m.streamLength step 1

		'Add the next character in the stream to the working string
		workingString = workingString + m.stream.mid( m.position, 1 )
		m.position = m.position + 1

		if workingString.trim() = ""
			workingString = workingString.trim()

		'If we just returned a newline, reset the working string, otherwise return a newline
		else if workingString.trim() = "^"
			numTokens = m.tokens.count()
			if numTokens > 0 and m.tokens[numTokens-1].nodeType = "newline"
				workingString = ""
			else
				return newNewlineNode()
			end if

		'Try and make a hyperlink node
		else if workingString.trim() = "<"

			while m.aRegex.isMatch( workingString ) = false

				if m.position >= m.streamLength
					return newTextNode( workingString )
				end if
				workingString = workingString + m.stream.mid(m.position,1)
				m.position = m.position + 1

			end while

			hrefRegex = createObject( "roRegex", "href=(" + Chr(34) + "|')([^'" + Chr(34) + "]*)(" + Chr(34) + "|')", "is" )
			textRegex =createObject( "roRegex", ">(.*)</", "is" )

			link = ""
			text = ""

			if hrefRegex.isMatch( workingString )
				matches = hrefRegex.match( workingString )
				link = matches[2]
			end if

			if textRegex.isMatch( workingString )
				matches = textRegex.match( workingString )
				text = matches[1]
			end if

			return newLinkNode( text, link )
		
		'Make a text node if next character starts a link/newline/eof node
		else if (i = m.streamLength-1) or (m.stream.mid(m.position, 1) = "^") or (m.stream.mid(m.position, 1) = "<")
			return newTextNode( workingString )

		end if		
	end for

	return newEOFNode()
end function


''
' Get the token at the input line
' @param - Int - The line number to get data for
' @return - Object - Node
''
function lexerGetTokenAt( lineNumber ) as Object

	'Populate the lexer's internal cache until we get to the point we're trying to reach
	while lineNumber >= m.tokens.count()

		'Get the next raw token
		latestToken = m.getToken()

		'If needed, split it up into multiple 1-line tokens
		if latestToken.nodeType <> "EOF" and latestToken.nodeType <> "newline"

			line = ""
			words = latestToken.text.tokenize( " " )
			for each word in words
				currentLength = m.font.getOneLineWidth( line, m.remainingWidth )
				newWordLength = m.font.getOneLineWidth( word + " ", m.remainingWidth )

				if line = ""
					line = word
				else if currentLength + newWordLength < m.remainingWidth 
					line = line + " " + word
				else
					if latestToken.nodeType = "link"
						m.tokens.push( newLinkNode( line, latestToken.url ) )
					else
						m.tokens.push( newTextNode( line ) )
					end if

					line = word
				end if
			end for

			if line <> ""
				if latestToken.nodeType = "link"
					m.tokens.push( newLinkNode( line, latestToken.url ) )
				else
					m.tokens.push( newTextNode( line ) )
				end if
			end if
		else
			m.tokens.push( latestToken )
		end if
	end while

	return m.tokens[lineNumber]
end function
