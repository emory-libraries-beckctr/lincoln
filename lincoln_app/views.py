# Create your views here.
import os
import re
from urllib import urlencode
import tempfile, zipfile
from django.core.servers.basehttp import FileWrapper
import mimetypes

from django.conf import settings
from django.shortcuts import render, render_to_response
from django.http import HttpResponse, Http404
from django.core.paginator import Paginator, InvalidPage, EmptyPage, PageNotAnInteger
from django.template import RequestContext
from django.shortcuts import redirect
from django.contrib import messages

from lincoln_app.models import DocTitle, Doc, Bibliography, SourceDescription, DocSearch, PageImage
from lincoln_app.forms import DocSearchForm

from eulcommon.djangoextras.http.decorators import content_negotiation
from eulexistdb.query import escape_string
from eulexistdb.exceptions import DoesNotExist
from eulexistdb.db import ExistDBException

def index(request):
   return render(request, 'index.html')

def overview(request):
   return render(request, 'overview.html')

def contents(request):
    #return_fields = ['author', 'title', 'date', 'pubplace']
    docs = Doc.objects.only('author', 'title', 'date', 'pubplace', 'xml_id')
    number_of_results = 20
    context = {}
    docs_paginator = Paginator(list(docs), number_of_results)
    
    try:
        page = int(request.GET.get('page', '1'))
    except ValueError:
        page = 1
    try:
        docs_page = docs_paginator.page(page)
    except (EmptyPage, InvalidPage):
        docs_page = docs_paginator.page(paginator.num_pages)

    context['docs_paginated'] = docs_page
    return render_to_response('contents.html', context, context_instance=RequestContext(request))

def doc_display(request, doc_id):
  "Display the contents of a single document."
  return_fields = ['doct__publisher', 'doct__rights', 'doct__publication_date', 'doct__relation', 'doct__source', 'doct__project_desc']
  context = {}
  try:
      doc = Doc.objects.also(*return_fields).get(id=doc_id)
      context['doc'] = doc
      print doc.serialize()
      format = doc.xsl_transform(filename=os.path.join(settings.BASE_DIR, '..', 'lincoln_app', 'xslt', 'sermon.xsl'))
      #print format
      context['format'] = format.serialize()
      #print format.serialize()
      return render_to_response('doc_display.html', context, context_instance=RequestContext(request))
      #return render(request, 'doc_display.html', {'doc': doc, 'format': format.serialize()})
  except DoesNotExist:
      raise Http404

def keyword_display(request, doc_id):
    "Display the keyword in context a single document."
    if 'keyword' in request.GET:
        search_terms = request.GET['keyword']
        url_params = '?'+urlencode({'keyword': search_terms})
        highlighter = {'highlight': search_terms}
    else:
        url_params = ''
        highlighter = {}
    context = {}
    try:
        doc = Doc.objects.filter(**highlighter).get(id=doc_id).filter(xml_id=doc_id).get(imagefacs=imageid)
        context['doc'] = doc
        format = doc.xsl_transform(filename=os.path.join(settings.BASE_DIR, '..', 'lincoln_app', 'xslt', 'kwic.xsl'))
        context['format'] = format.serialize()
        return render_to_response('keyword.html', context, context_instance=RequestContext(request))
    except DoesNotExist:
        raise Http404

def searchbox(request):
    query_error = False
    "Search documents by keyword/title/author/date/place"
    form = DocSearchForm(request.GET)
    response_code = None
    context = {'searchbox': form}
    search_opts = {}
    number_of_results = 10
    special = DocTitle()
    size = 0
    
    if form.is_valid():
        if 'title' in form.cleaned_data and form.cleaned_data['title']:
            search_opts['title__fulltext_terms'] = '%s' % form.cleaned_data['title']
        if 'author' in form.cleaned_data and form.cleaned_data['author']:
            search_opts['author__fulltext_terms'] = '%s' % form.cleaned_data['author']
        if 'keyword' in form.cleaned_data and form.cleaned_data['keyword']:
            search_opts['fulltext_terms'] = '%s' % form.cleaned_data['keyword']
        if 'sermon_Date' in form.cleaned_data and form.cleaned_data['sermon_Date']:
            search_opts['date__fulltext_terms'] = '%s' % form.cleaned_data['sermon_Date']
        if 'Place_of_Publication' in form.cleaned_data and form.cleaned_data['Place_of_Publication']:
            search_opts['pubplace__fulltext_terms'] = '%s' % form.cleaned_data['Place_of_Publication']

        try:
            #docs = DocTitle.objects.only('id', 'title', 'date', 'author', 'pubplace').filter(**search_opts).order_by('title')
            docs = DocTitle.objects.filter(**search_opts)
            #if 'keyword' in form.cleaned_data and form.cleaned_data['keyword']:
                #docs = docs.only_raw(line_matches='%%(xq_var)s//text[ft:query(., "%s")]' \
                                  # % escape_string(form.cleaned_data['keyword']))
    
            docums = docs.all()
            for d in list(docums):
               if len(d.title) == 3:
                  size += 3
               else:
                  size += 1
    
            print size
            searchbox_paginator = Paginator(docums, number_of_results)
            
            try:
                page = int(request.GET.get('page', '1'))
            except ValueError:
                page = 1
            # If page request (9999) is out of range, deliver last page of results.
            try:
                searchbox_page = searchbox_paginator.page(page)
            except (EmptyPage, InvalidPage):
                searchbox_page = searchbox_paginator.page(paginator.num_pages)

            context['docs_paginated'] = searchbox_page
            context['size'] = range(1, size)
            context['title'] = form.cleaned_data['title']
            context['author'] = form.cleaned_data['author']
            context['keyword'] = form.cleaned_data['keyword']
            context['date'] = form.cleaned_data['sermon_Date']
            context['place'] = form.cleaned_data['Place_of_Publication']
           
            response = render_to_response('search.html', context, context_instance=RequestContext(request))
            #no search conducted yet, default form

        except ExistDBException as e:
            query_error = True
            if 'Cannot parse' in e.message():
                messages.error(request, 'Your search query could not be parsed.  ' + 'Please revise your search and try again.')
            else:
                # generic error message for any other exception
                messages.error(request, 'There was an error processing your search.')
            response = render(request, 'search.html',{'searchbox': form, 'request': request})


    else:
        response = render(request, 'search.html', {"searchbox": form})
       
    if response_code is not None:
        response.status_code = response_code
    if query_error:
        response.status_code = 400

    return response

def page_image(request, doc_id, image_id):
    "Display a page; navigate through the pages."
    return_fields = ['nextpage', 'prevpage', 'pageimage', 'pagenum', 'paget__title', 'paget__author']
    page = PageImage.objects.also(*return_fields).filter(divid=doc_id).get(pageimage=image_id) 
    context = {}
    print page.serialize() #debug:show in console
    try:
        context['page'] = page
        context['doc_id'] = doc_id
        context['image_id'] = image_id
        return render_to_response('page.html', context, context_instance=RequestContext(request)) 
    except DoesNotExist:
        raise Http404
    #Boardman (3 sermons in 1 doc) is a problem here: the pages continue so we get DoesNotExist for page 27, which is in the next section. How to gracefully return the reader to the sermon?
def send_file(request, basename):
    if basename == 'lincoln_sermons':
        extension = '.zip'
    else:
        extension = '.txt'
    filepath = 'static/txt/' + re.sub(r'\.001', '', basename) + extension
    filename  = os.path.join(settings.BASE_DIR, filepath )
    download_name = basename + extension
    wrapper      = FileWrapper(open(filename))
    content_type = mimetypes.guess_type(filename)[0]
    response     = HttpResponse(wrapper,content_type=content_type)
    response['Content-Length']      = os.path.getsize(filename)    
    response['Content-Disposition'] = "attachment; filename=%s"%download_name
    return response

#def oai(request, verb)
#   "Display any one of the verbs of OAI: Identify, ListRecords, GetRecord, ListIdentifiers, ListMetadataFormats, ListSets"
#  verb = verb.GET #cleandata?
#  verblist = ['Identify', 'ListRecords', 'ListIdentfiers', 'GetRecord', 'ListSets', 'ListMetadataFormats']
#  if verb in verb list:


