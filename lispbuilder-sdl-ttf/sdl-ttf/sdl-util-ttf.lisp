;; This file contains some useful functions for using SDL_ttf from Common lisp
;; 2006 (c) Rune Nesheim, see LICENCE.

(in-package #:lispbuilder-sdl-ttf)

;;; Macros


(pushnew 'init-ttf sdl:*external-init-on-startup*)

(pushnew 'quit-ttf sdl:*external-quit-on-exit*)

(defun is-init ()
  "Queries the initialization status of the truetype library. 
Returns T if already initialized and NIL if uninitialized."
  (sdl-ttf-cffi::ttf-was-init))


;;; w

(defmacro with-init (() &body body)
  "Initialises the truetype font library. Will exit if the libary cannot be initialised. 
WITH-INIT must be called before using other functions in this library. 
LISPBUILDER-SDL does not have to be initialized prior to this call."
  `(unwind-protect
	(progn
	  (init-ttf)
	  ,@body)
     (close-font :font *default-font*)
     (quit-ttf)))

(defmacro with-open-font ((font-name size &optional font-path) &body body)
  "This is a convenience macro that will first attempt to intialize the truetype font library 
of FONT-NAME by calling WITH-INIT, and if successfull open the specified truetype font using OPEN-FONT. 
Will exit if the library cannot be initialized or the font cannot be opened. 

Binds *default-font* to the font in font-name. 

Several truetype fonts or font sizes may be opened for use within a single SDL application.
However only a single FONT may be open at any one time. WITH-OPEN-FONT calls may not be nested.

FONT-NAME is the name of the truetype font to be opened, of type STRING

SIZE is the size of the font, as an INTEGER

FONT-PATH is the path to the font, of type STRING"
  `(with-init ()
     (when (typep *default-font* 'font)
       (error "WITH-OPEN-FONT; *default-font* is already bound to a FONT."))
     (when (initialise-font ,font-name ,size ,font-path)
       ,@body
       (close-font :font *default-font*)
       (setf *default-font* nil))))

;;; Functions

(defun init-ttf ()
  "Initializes the font library if uninitialized and returns T, 
or else returns NIL if uninitialized."
  (if (is-init)
      t
      (sdl-ttf-cffi::ttf-init)))

(defun quit-ttf ()
  "Uninitializes the font library if initialized. Returns NIL."
  (if (is-init)
      (sdl-ttf-cffi::ttf-quit)))

(defun initialise-font (filename pathname size)
  "Binds *DEFAULT-FONT* to a FONT file FILENAME at PATHNAME, of size SIZE.
Closes any previous font that is already bound to *DEFAULT-FONT*.
Automatically initilises the font library if uninitialised 
at FONT load time. 

FILENAME is the file name of the FONT, of type STRING.

PATHNAME is the pathname of the FONT, of type STRING.

SIZE is the size of the font to initialise, of type INTEGER."
  (when (is-init)
    (close-font :font *default-font*))
  (init-ttf)
  (setf *default-font* (open-font filename size pathname)))

(defun initialise-default-font ()
  "Binds *DEFAULT-FONT* to a FONT file FILENAME at PATHNAME, of size SIZE.
Closes any previous font that is already bound to *DEFAULT-FONT*.

FILENAME is the file name of the FONT, of type STRING.

PATHNAME is the pathname of the FONT, of type STRING.

SIZE is the size of the font to initialise, of type INTEGER."
  (initialise-font "Vera.ttf" *default-font-path* 32))

(defun close-font (&key font *default-font*)
  "Closes the font FONT when the font library is intitialized, and returns T.
Returns NIL if the font cannot be closed or the font library is not initialized.
Does not uninitialise the font library."
  (if (is-init)
      (if (typep font 'font)
	  (free-font font)))
  (setf font nil))

;;; g

(defun get-Glyph-Metric (ch &key metric (font *default-font*))
  "Returns the specified glyph metrics for the character CH, or NIL upon error. 
The glyph metrics are specified by the keyword parameter :METRIC.

FONT is a FONT object from which to retrieve the glyph metrics of the character CH.

CH is a UNICODE chararacter specified as an INTEGER.

:METRIC may be one of: 
  :MINX , for the minimum X offset
  :MAXX , for the maximum X offset
  :MINY , for the minimum Y offset
  :MAXY , for the maximum Y
  :ADVANCE , for the advance offset

RESULT is the glyph metric returend as an INTEGER."
  (let ((p-minx (cffi:null-pointer))
	(p-miny (cffi:null-pointer))
	(p-maxx (cffi:null-pointer))
	(p-maxy (cffi:null-pointer))
	(p-advance (cffi:null-pointer))
	(val nil)
	(r-val nil))
    (cffi:with-foreign-objects ((minx :int) (miny :int) (maxx :int) (maxy :int) (advance :int))
      (case metric
	(:minx (setf p-minx minx))
	(:miny (setf p-miny miny))
	(:maxx (setf p-maxx maxx))
	(:maxy (setf p-maxy maxy))
	(:advance (setf p-advance advance)))
      (setf r-val (sdl-ttf-cffi::ttf-Glyph-Metrics font ch p-minx p-maxx p-miny p-maxy p-advance))
      (if r-val
	  (cond
	    ((sdl:is-valid-ptr p-minx)
	     (setf val (cffi:mem-aref p-minx :int)))
	    ((sdl:is-valid-ptr miny)
	     (setf val (cffi:mem-aref p-miny :int)))
	    ((sdl:is-valid-ptr maxx)
	     (setf val (cffi:mem-aref p-maxx :int)))
	    ((sdl:is-valid-ptr maxy)
	     (setf val (cffi:mem-aref p-maxy :int)))
	    ((sdl:is-valid-ptr advance)
	     (setf val (cffi:mem-aref p-advance :int))))
	  (setf val r-val)))
    val))

(defun get-Font-Size (text &key size encoding (font *default-font*))
  "Calculates and returns the resulting SIZE \(width or height\) of the SDL:SURFACE required to render the 
font FONT, or NIL on error.
No actual rendering is performed however correct kerning is calculated for the actual width. 
The height returned is the same as returned using GET-FONT-HEIGHT. 

FONT is the font from which to calculate the size of the string.

TEXT is the LATIN1 string to size. 

:SIZE may be one of: 
  :W , text width
  :H , text height

:ENCODING may be one of: 
  :TEXT
  :UTF8
  :UNICODE

Returns the width or height of the specified SDL:SURFACE, or NIL upon error."
  (let ((p-w (cffi:null-pointer))
	(p-h (cffi:null-pointer))
	(val nil)
	(r-val nil))
    (cffi:with-foreign-objects ((w :int) (h :int))
      (case size
	(:w (setf p-w w))
	(:h (setf p-h h)))
      (case encoding
	(:TEXT (setf r-val (sdl-ttf-cffi::ttf-Size-Text (fp-font font) text p-w p-h)))
	(:UTF8 (setf r-val (sdl-ttf-cffi::ttf-Size-UTF8 (fp-font font) text p-w p-h))))
      (if r-val
	  (cond
	    ((sdl:is-valid-ptr p-w)
	     (setf val (cffi:mem-aref p-w :int)))
	    ((sdl:is-valid-ptr p-h)
	     (setf val (cffi:mem-aref p-h :int))))
	  (setf val r-val)))
    val))

(defun get-font-style (&key (font *default-font*))
  "Returns the rendering style of font. If no style is set then :STYLE-NORMAL is returned, 
or NIL upon error.
  
FONT is a FONT object. 

Retuns the font style as one or more of:
  :STYLE-NORMAL
  :STYLE-NORMAL
  :STYLE-BOLD
  :STYLE-ITALIC
  :STYLE-UNDERLINE"
  (sdl-ttf-cffi::ttf-Get-Font-Style (fp-font font)))

(defun get-font-height (&key (font *default-font*))
  "Returns the maximum pixel height of all glyphs of font FONT. 
Use this height for rendering text as close together vertically as possible, 
though adding at least one pixel height to it will space it so they can't touch. 
Remember that SDL_ttf doesn't handle multiline printing, so you are responsible 
for line spacing, see GET-FONT-LINE-SKIP as well. 

FONT is a FONT object. 

Retuns the height of the font as an INTEGER."
  (sdl-ttf-cffi::ttf-Get-Font-height (fp-font font)))

(defun get-font-ascent (&key (font *default-font*))
  "Returns the maximum pixel ascent of all glyphs of font FONT. 
This can also be interpreted as the distance from the top of the font to the baseline. 
It could be used when drawing an individual glyph relative to a top point, 
by combining it with the glyph's maxy metric to resolve the top of the rectangle used when 
blitting the glyph on the screen. 

FONT is a FONT object. 

Returns the ascent of the font as an INTEGER."
  (sdl-ttf-cffi::ttf-Get-Font-Ascent (fp-font font)))

(defun get-font-descent (&key (font *default-font*))
  "Returns the maximum pixel descent of all glyphs of font FONT. 
This can also be interpreted as the distance from the baseline to the bottom of the font. 
It could be used when drawing an individual glyph relative to a bottom point, 
by combining it with the glyph’s maxy metric to resolve the top of the rectangle used when 
blitting the glyph on the screen. 

FONT is a FONT object. 

Returns the descent of the font as an INTEGER."
  (sdl-ttf-cffi::ttf-Get-Font-Descent (fp-font font)))

(defun get-font-line-skip (&key (font *default-font*))
  "Returns the recommended pixel height of a rendered line of text of the font FONT. 
This is usually larger than the GET-FONT-HEIGHT of the font. 

FONT is a FONT object. 

Returns the pixel height of the font as an INTEGER."
  (sdl-ttf-cffi::ttf-Get-Font-Line-Skip (fp-font font)))

(defun get-font-faces (&key (font *default-font*))
  "Returns the number of faces 'sub-fonts' available in the font FONT. 
This is a count of the number of specific fonts (based on size and style and other
 typographical features perhaps) contained in the font itself. It seems to be a useless
 fact to know, since it can’t be applied in any other SDL_ttf functions.

FONT is a FONT object. 

Returns the number of faces in the FONT as an INTEGER."
  (sdl-ttf-cffi::ttf-Get-Font-faces (fp-font font)))

(defun is-font-face-fixed-width (&key (font *default-font*))
  "Returns T if the font face is of a fixed width, or NIL otherwise. 
Fixed width fonts are monospace, meaning every character that exists in the font is the same width. 

FONT is a FONT object. 

Retuns T FONT is of fixed width, and NIL otherwise."
  (sdl-ttf-cffi::ttf-Get-Font-face-is-fixed-width (fp-font font)))

(defun get-font-face-family-name (&key (font *default-font*))
  "Returns the current font face family name of font FONT or NIL if the information is unavailable. 

FONT is a FONT object. 

Returns the name of the font face family name as a STRING, or NIL if unavailable."
  (sdl-ttf-cffi::ttf-Get-Font-face-Family-Name (fp-font font)))

(defun get-font-face-style-name (&key (font *default-font*))
  "Returns the current font face style name of font FONT, or NIL if the information is unavailable. 

FONT is a FONT object. 

Returns the name of the font face style as a STRING, or NIL if unavailable."
  (sdl-ttf-cffi::ttf-Get-Font-face-Style-Name (fp-font font)))

;;; i


;;; o

(defun open-font (filename size &optional (pathname nil))
  "Attempts to open the specified truetype font. 
Returns a FONT object if successful, returns NIL if unsuccessful.

FILENAME is the name of the truetype font to be opened, of type STRING
PATHNAME is the path to the truetype font to be opened, of type STRING

SIZE is the size of the font, as an INTEGER 

Returns a new FONT, or NIL upon error."
  (let* ((fontname (namestring (if pathname
				   (merge-pathnames filename pathname)
				   filename)))
	 (font (new-font (sdl-ttf-cffi::ttf-Open-Font fontname size))))
    (unless font
      (error (concatenate 'string "Failed to open font in location: " filename)))
    font))

;;; r

(defun draw-string-solid (text position &key 
			  (encoding :text)
			  (type :solid)
			  (style :normal)
			  (font *default-font*)
			  (surface sdl:*default-surface*)
			  (color sdl:*default-color*)
			  update-p)
  "See DRAW-STRING-SOLID-*.
:POSITION is the x/y position to render the text, or type SDL:POINT."
  (draw-string-solid-* text (sdl:x position) (sdl:y position)
		       :encoding encoding
		       :type type
		       :style style
		       :font font
		       :surface surface
		       :color color
		       :update-p update-p))

(defun draw-string-solid-* (text x y &key 
			    (encoding :text)
			    (type :solid)
			    (style :normal)
			    (font *default-font*)
			    (surface sdl:*default-surface*)
			    (color sdl:*default-color*)
			    update-p)
  "Render text TEXT using font :FONT with color :COLOR onto surface :SURFACE, 
using the Solid mode. 

x/y are the x and y position coordinates, as INTEGERS.

TEXT is the text to render when TEXT may be of LATIN1, UTF8, UNICODE, GLYPH. The TEXT specified
must match :ENCODING.

:ENCODING specifies the format of the text to render and is one of: 
  :LATIN1
  :UTF8
  :UNICODE
  :GLYPH

:SURFACE is the surface to render text onto, of type SDL:SURFACE 

:COLOR color is the color used to render text, of type SDL:COLOR-STRUCT

:UPDATE-P will update the SURFACE when T."
  (unless (typep font 'font)
    (error "ERROR: draw-string-solid-*; FONT must be of type FONT."))
  (unless (typep surface 'sdl:sdl-surface)
    (error "ERROR: draw-string-solid-*; SURFACE must be of type SDL:SDL-SURFACE."))
  (unless (typep color 'sdl:sdl-color)
    (error "ERROR: draw-string-solid-*; COLOR must be of type SDL:SDL-COLOR."))  
  (case encoding
    (:text
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (col-struct color)
       (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-Text-Solid (fp-font font) text col-struct))))
     (sdl:set-surface-* (cached-surface font) :x x :y y)
     (sdl:blit-surface (cached-surface font) surface))
    (:UTF8
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (col-struct color)
       (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-UTF8-Solid (fp-font font) text col-struct))))
     (sdl:set-surface-* (cached-surface font) x y)
     (sdl:blit-surface (cached-surface font) surface))
    (:GLYPH
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (col-struct color)
       (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-Glyph-Solid (fp-font font) text col-struct))))
     (sdl:set-surface-* (cached-surface font) x y)
     (sdl:blit-surface (cached-surface font) surface))
    (:UNICODE
     ;; (defun draw-text-UNICODE-solid (surface font text color position &key update-p)
     ;;   (let ((text-surf (RenderUNICODE-Solid font text color)))
     ;;     (if text-surf
     ;; 	(sdl:blit-surface text-surf surface :dst-rect position :update-p update-p))))
     nil)))

(defun draw-string-shaded (text position fg-color bg-color &key
			     (encoding :text)
			     (type :shaded)
			     (style :normal)
			     (font *default-font*)
			     (surface sdl:*default-surface*)
			     update-p)
  "See DRAW-STRING-SHADED-*"
  (draw-string-shaded-* text (sdl:x position) (sdl:y position) fg-color bg-color
			:encoding encoding
			:type type
			:style style
			:font font
			:surface surface
			:update-p update-p))

(defun draw-string-shaded-* (text x y fg-color bg-color &key
			     (encoding :text)
			     (type :shaded)
			     (style :normal)
			     (font *default-font*)
			     (surface sdl:*default-surface*)
			     update-p)
  "Render text TEXT using font :FONT with foreground color FG-COLOR and background color BG-COLOR 
onto surface :SURFACE, using the Shaded mode. 

FONT is a FONT object.

TEXT is the text to render when TEXT may be of LATIN1, UTF8, UNICODE, GLYPH. The TEXT specified
must match :ENCODING.

FG-COLOR is the foreground color of the text, of type SDL:COLOR-STRUCT 

BG-COLOR is the background color of the text, of type SDL:COLOR-STRUCT 

:ENCODING specifies the format of the text to render and is one of: 
  :LATIN1
  :UTF8
  :UNICODE
  :GLYPH

:POSITION is the x/y position to render the text, or type SDL:POINT.

:SURFACE is the surface to render text onto, of type SDL:SURFACE 

:UPDATE-P will update the SURFACE when T."
  (unless (typep font 'font)
    (error "ERROR: draw-string-shaded-*; FONT must be of type FONT."))
  (unless (typep surface 'sdl:sdl-surface)
    (error "ERROR: draw-string-shaded-*; SURFACE must be of type SDL:SDL-SURFACE."))
  (unless (typep fg-color 'sdl:sdl-color)
    (error "ERROR: draw-string-shaded-*; FG-COLOR must be of type SDL:SDL-COLOR."))
  (unless (typep bg-color 'sdl:sdl-color)
    (error "ERROR: draw-string-shaded-*; BG-COLOR must be of type SDL:SDL-COLOR."))  
  (case encoding
    (:text
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (fg-struct fg-color)
       (sdl:with-foreign-color-copy (bg-struct bg-color)
	 (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-Text-shaded (fp-font font)
											text fg-struct bg-struct)))))
     (sdl:set-surface-* (cached-surface font) :x x :y y)
     (sdl:blit-surface (cached-surface font) surface))
    (:UTF8
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (fg-struct fg-color)
       (sdl:with-foreign-color-copy (bg-struct bg-color)
	 (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-UTF8-shaded (fp-font font)
											text fg-struct bg-struct)))))
     (sdl:set-surface-* (cached-surface font) :x x :y y)
     (sdl:blit-surface (cached-surface font) surface))
    (:GLYPH
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (fg-struct fg-color)
       (sdl:with-foreign-color-copy (bg-struct bg-color)
	 (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-Glyph-shaded (fp-font font)
											 text fg-struct bg-struct)))))
     (sdl:set-surface-* (cached-surface font) :x x :y y)
     (sdl:blit-surface (cached-surface font) surface))
    (:UNICODE
     ;; (defun draw-text-UNICODE-solid (surface font text color position &key update-p)
     ;;   (let ((text-surf (RenderUNICODE-Solid font text color)))
     ;;     (if text-surf
     ;; 	(sdl:blit-surface text-surf surface :dst-rect position :free-src t :update-p update-p))))
     nil)))

(defun draw-string-blended (text position &key
			    (encoding :text)
			    (type :blended)
			    (style :normal)
			    (font *default-font*)
			    (surface sdl:*default-surface*)
			    (color sdl:*default-color*)
			    update-p)
  "See DRAW-STRING-BLENDED-*."
  (draw-string-blended-* text (sdl:x position) (sdl:y position)
			 :encoding encoding
			 :type type
			 :style style
			 :font font
			 :surface surface
			 :color color
			 :upadate-p update-p))

(defun draw-string-blended-* (text x y &key
			      (encoding :text)
			      (type :blended)
			      (style :normal)
			      (font *default-font*)
			      (surface sdl:*default-surface*)
			      (color sdl:*default-color*)
			      update-p)
  "Render text TEXT using font :FONT with color :COLOR onto surface :SURFACE, 
using the Blended mode. 

FONT is a FONT object.

TEXT is the text to render when TEXT may be of LATIN1, UTF8, UNICODE, GLYPH. The TEXT specified
must match :ENCODING.


:ENCODING specifies the format of the text to render and is one of: 
  :LATIN1
  :UTF8
  :UNICODE
  :GLYPH

:POSITION is the x/y position to render the text, or type SDL:POINT.

:SURFACE is the surface to render text onto, of type SDL:SURFACE 

:COLOR color is the color used to render text, of type SDL:COLOR-STRUCT

:UPDATE-P will update the SURFACE when T."
  (unless (typep font 'font)
    (error "ERROR: draw-string-blended-*; FONT must be of type FONT."))
  (unless (typep surface 'sdl:sdl-surface)
    (error "ERROR: draw-string-blended-*; SURFACE must be of type SDL:SDL-SURFACE."))
  (unless (typep color 'sdl:sdl-color)
    (error "ERROR: draw-string-blended-*; COLOR must be of type SDL:SDL-COLOR."))  
  (case encoding
    (:text
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (col-struct color)
       (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-Text-blended (fp-font font) text color))))
     (sdl:set-surface-* (cached-surface font) :x x :y y)
     (sdl:blit-surface (cached-surface font) surface))
    (:UTF8
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (col-struct color)
       (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-UTF8-blended (fp-font font) text color))))
     (sdl:set-surface-* (cached-surface font) :x x :y y)
     (sdl:blit-surface (cached-surface font) surface))
    (:GLYPH
     (when (cached-surface font)
       (sdl:free-surface (cached-surface font)))
     (sdl:with-foreign-color-copy (col-struct color)
       (setf (cached-surface font) (sdl:surface (sdl-ttf-cffi::ttf-Render-Glyph-blended (fp-font font) text color))))
     (sdl:set-surface-* (cached-surface font) :x x :y y)
     (sdl:blit-surface (cached-surface font) surface))
    (:UNICODE
     ;; (defun draw-text-UNICODE-solid (surface font text color position &key update-p)
     ;;   (let ((text-surf (RenderUNICODE-Solid font text color)))
     ;;     (if text-surf
     ;; 	(sdl:blit-surface text-surf surface :dst-rect position  :update-p update-p))))
     nil)))

;;; s

(defun set-font-style (style &key (font *default-font*))
  "Sets the rendering style STYLE of font FONT. This will flush the internal cache of previously 
rendered glyphs, even if there is no change in style, so it may be best to check the
 current style using GET-FONT-STYLE first. 

NOTE: Combining :STYLE-UNDERLINE with anything can cause a segfault, other combinations 
may also do this. 

FONT is a FONT object. 

STYLE is a list of one or more: 
  :STYLE-NORMAL
  :STYLE-BOLD
  :STYLE-ITALIC
  :STYLE-UNDERLINE"
  (sdl-ttf-cffi::ttf-Set-Font-Style (fp-font font) style))
