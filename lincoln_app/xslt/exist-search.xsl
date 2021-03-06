<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:exist="http://exist.sourceforge.net/NS/exist"
  version="1.0" exclude-result-prefixes="exist">

  <xsl:output method="xml" omit-xml-declaration="yes"/>

  <xsl:param name="mode">search</xsl:param>	 <!-- browse or search -->

  <!-- search terms -->
  <xsl:param name="title"/>
  <xsl:param name="author"/>
  <xsl:param name="date"/>
  <xsl:param name="keyword"/>


  <xsl:variable name="url_suffix">keyword=<xsl:value-of select="$keyword"/>&amp;title=<xsl:value-of select="$title"/>&amp;date=<xsl:value-of select="$date"/>&amp;author=<xsl:value-of select="$author"/></xsl:variable>

  <!-- information about current set of results  -->
  <xsl:variable name="position"><xsl:value-of select="//@exist:start"/></xsl:variable>
  <xsl:param name="max"/>
  <xsl:variable name="total"><xsl:value-of select="//@exist:hits"/></xsl:variable>

<!--  <xsl:include href="utils.xsl"/> -->
  <xsl:include href="common.xsl"/>

  <xsl:variable name="nl"><xsl:text> 
</xsl:text></xsl:variable>


  <xsl:template match="/">
    <xsl:call-template name="itemlist"/>
  </xsl:template>

  <xsl:template name="itemlist">
    <xsl:if test="count(//item) > 0">

    <xsl:call-template name="total-jumplist"/>
    
    <xsl:if test="//item/hits">
      <p class="info">Click on the number of hits to see your search terms in context.</p>
    </xsl:if>

      <table class="browse">
        <thead style="font-size:small;">
        <tr>
          <xsl:if test="//hits"><th class="hits">hits</th></xsl:if>
          <th class="num">#</th>
          <xsl:if test="//title"><th>title</th></xsl:if>
          <xsl:if test="//author"><th>author</th></xsl:if>
          <xsl:if test="//date"><th>date</th></xsl:if>

      </tr>
    </thead>
    <tbody align="left" valign="top" style="font-size:small;">
      <xsl:apply-templates select="//item"/>
    </tbody>
  </table>
</xsl:if>
  
  </xsl:template>

  <xsl:template match="item">
    <tr>	<!-- calculate item's position in total result set -->
    <xsl:apply-templates select="hits" mode="table"/>
      <td class="num" width="4%"><xsl:value-of select="position() + $position - 1"/>.</td>
      <xsl:value-of select="$nl"/>

      <!--      <xsl:apply-templates select="*[not(self::hits)]" mode="table"/> -->

      <!-- there should ALWAYS be a table cell for a field if any of
      the records include that field (e.g., some texts that have no date) -->

      <xsl:if test="head//title">
	<td class="title"><xsl:element name="a">
	  <xsl:attribute name="href">sermon.php?id=<xsl:value-of
	select="@id"/>
	  <xsl:if test="$keyword !=''">&amp;keyword=<xsl:value-of
	  select="$keyword"/></xsl:if>
	  </xsl:attribute>
	  <xsl:apply-templates select="head//title" mode="table"/>
	</xsl:element></td>
      </xsl:if>
      <xsl:if test="head//author">
        <td class="author"  width="20%">
<xsl:apply-templates select="head//author" />
    </td>
      </xsl:if>
      <xsl:if test="head/bibl/date">
        <td class="date"  width="25%"><xsl:apply-templates select="head/bibl/date" mode="table"/></td>
      </xsl:if>
    </tr>
    <xsl:value-of select="$nl"/>
  </xsl:template>

  <xsl:template match="item/*" mode="table">
    <xsl:if test="name() != 'id'">
      <xsl:apply-templates select="."/>
    </xsl:if>
  </xsl:template>


  <xsl:template match="item/hits" mode="table">
    <td class="hits">
      <a>
        <xsl:attribute name="href">kwic.php?id=<xsl:value-of
	select="../@id"/>&amp;keyword=<xsl:value-of select="$keyword"/></xsl:attribute>
        <xsl:apply-templates select="."/>
      </a>
    </td>
    <xsl:value-of select="$nl"/>
  </xsl:template>


<!-- possibly multiple names in table mode -->
<xsl:template match="item/name">
  <a>
    <xsl:attribute name="href">search.php?author=<xsl:value-of select="normalize-space(.)"/></xsl:attribute>
    <xsl:apply-templates/>
  </a>
  <xsl:if test="position() != last()">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>


<!-- do nothing with id itself --> <xsl:template match="id"/>

<xsl:template name="total-jumplist">


  <!-- only display total & jump list if there are actually results -->
  <xsl:if test="$total > 0">

    <xsl:variable name="url">search.php?<xsl:value-of select="$url_suffix"/>
  </xsl:variable>

  <table class="searchnav">
      <!-- always build a table with four cells so spacing will be consistent -->
      <tr>
      <xsl:choose>
        <xsl:when test="$position != 1">

          <!-- start position for previous chunk -->
        <xsl:variable name="newpos">
          <!-- start position shouldn't go below 1 -->
          <xsl:call-template name="max">
            <xsl:with-param name="num1"><xsl:value-of select="($position - $max)"/></xsl:with-param>
            <xsl:with-param name="num2"><xsl:value-of select="1"/></xsl:with-param>
          </xsl:call-template>
        </xsl:variable>

          <td>
            <!-- don't display first if it is the same as previous -->
            <xsl:if test="$newpos != 1">
              <a>
                <xsl:attribute name="href"><xsl:value-of 
                select="concat($url, '&amp;position=1&amp;max=', $max)"/></xsl:attribute>
                &lt;&lt; First
              </a>
            </xsl:if>
        </td>          


        <td>
          <a>
            <xsl:attribute name="href"><xsl:value-of 
            select="concat($url, '&amp;position=', $newpos, '&amp;max=', $max)"/></xsl:attribute>
            &lt;Previous
          </a>          
        </td>
        </xsl:when>
        <xsl:otherwise>
          <td></td>	<!-- first -->
          <td></td>	<!-- prev  -->
        </xsl:otherwise>
      </xsl:choose>

      <!-- next -->

      <xsl:variable name="next-start">
        <xsl:value-of select="($position + $max)"/>
      </xsl:variable>

      <xsl:variable name="last-start">
        <xsl:value-of select="($total - $max + 1)"/>
      </xsl:variable>

      <xsl:choose>
        <xsl:when test="($next-start - 1) &lt; $total">
          <td>
            <a>
            <xsl:attribute name="href"><xsl:value-of 
            select="concat($url, '&amp;position=', $next-start, '&amp;max=', $max)"/></xsl:attribute>
            Next&gt;
          </a>          
        </td>

        <td>
          <!-- don't display last if it is the same as next -->
          <xsl:if test="$next-start != $last-start">
            <a>
              <xsl:attribute name="href"><xsl:value-of 
              select="concat($url, '&amp;position=', $last-start, '&amp;max=', $max)"/></xsl:attribute>
              Last&gt;&gt;
            </a>          
          </xsl:if>
          
        </td>
        </xsl:when>
        <xsl:otherwise>
          <td></td>	<!-- next -->
          <td></td>	<!-- last -->
        </xsl:otherwise>
      </xsl:choose>
    </tr>
    </table>


  <xsl:variable name="chunksize"><xsl:value-of select="$max"/></xsl:variable>  
    <!-- only display jump list if there are more results than displayed here. -->
    <xsl:if test="$total > $chunksize">
      <form id="jumpnav">
        <xsl:attribute name="action"><xsl:value-of select="$mode"/>.php</xsl:attribute>

            <input name="keyword" type="hidden">
              <xsl:attribute name="value"><xsl:value-of select="$keyword"/></xsl:attribute>
            </input>
            <input name="author" type="hidden">
              <xsl:attribute name="value"><xsl:value-of select="$author"/></xsl:attribute>
            </input>            <input name="title" type="hidden">
              <xsl:attribute name="value"><xsl:value-of select="$title"/></xsl:attribute>
            </input>            <input name="date" type="hidden">
              <xsl:attribute name="value"><xsl:value-of select="$date"/></xsl:attribute>
            </input>
        <input name="max" type="hidden">
          <xsl:attribute name="value"><xsl:value-of select="$max"/></xsl:attribute>
        </input>
        <select name="position" onchange="submit();">
          <xsl:call-template name="jumpnav-option"/>
        </select>
      </form>
    </xsl:if> 

    <xsl:element name="p">
      <xsl:value-of select="$total"/> match<xsl:if test="$total != 1">es</xsl:if> found
    </xsl:element>
  </xsl:if> 
</xsl:template>


<!-- recursive function to generates option values for jumpnav form 
     based on position, max, and total -->
<xsl:template name="jumpnav-option">
  <!-- position, max, and total are global -->
  <xsl:param name="curpos">1</xsl:param>	<!-- start at 1 -->
  
  <xsl:variable name="curmax">    
    <xsl:call-template name="min">
      <xsl:with-param name="num1">
        <xsl:value-of select="$curpos + $max - 1"/>
      </xsl:with-param>
      <xsl:with-param name="num2">
        <xsl:value-of select="$total"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:variable>

  <option> 
    <xsl:attribute name="value"><xsl:value-of select="$curpos"/></xsl:attribute>
    <!-- if this option is the content currently being displayed, mark as selected -->
    <xsl:if test="$curpos = $position">
      <xsl:attribute name="selected">selected</xsl:attribute>
    </xsl:if>
    <xsl:value-of select="$curpos"/> - <xsl:value-of select="$curmax"/>
  </option>

  <!-- if the end of this section is less than the total, recurse -->
  <xsl:if test="$total > $curmax">
    <xsl:call-template name="jumpnav-option">
      <xsl:with-param name="curpos">
        <xsl:value-of select="$curpos + $max"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<!-- return the smaller of two numbers -->
<xsl:template name="min">
  <xsl:param name="num1"/>
  <xsl:param name="num2"/>

  <xsl:choose>
    <xsl:when test="$num1 > $num2">
      <xsl:value-of select="$num2"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$num1"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- return the larger of two numbers -->
<xsl:template name="max">
  <xsl:param name="num1"/>
  <xsl:param name="num2"/>
  <xsl:choose>
    <xsl:when test="number($num1) > number($num2)">
      <xsl:value-of select="$num1"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$num2"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
