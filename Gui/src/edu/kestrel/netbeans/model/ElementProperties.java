/*
 * ElementProperties.java
 *
 * $Id$
 *
 *
 *
 * $Log$
 * Revision 1.3  2003/02/16 02:14:03  weilyn
 * Added support for defs.
 *
 * Revision 1.2  2003/02/13 19:39:29  weilyn
 * Added support for claims.
 *
 * Revision 1.1  2003/01/30 02:01:56  gilham
 * Initial version.
 *
 *
 *
 */

package edu.kestrel.netbeans.model;

/** Names of properties of elements.
 *
 */
public interface ElementProperties {
    public static final String PROP_MEMBERS = "members"; // NOI18N
    
    public static final String PROP_SPECS = "specs"; // NOI18N
    
    public static final String PROP_SORTS = "sorts"; // NOI18N
    
    public static final String PROP_OPS = "ops"; // NOI18N
    
    public static final String PROP_DEFS = "defs"; // NOI18N
    
    public static final String PROP_CLAIMS = "claims"; // NOI18N

    public static final String PROP_NAME = "name"; // NOI18N
    
    public static final String PROP_PARAMETERS = "parameters"; // NOI18N
    
    public static final String PROP_SORT = "sort"; // NOI18N
    
    public static final String PROP_STATUS = "status"; // NOI18N
    
    public static final String PROP_VALID = "valid"; // NOI18N
    
    public static final String PROP_CLAIM_KIND = "claim_kind"; // NOI18N    

    public static final String PROP_EXPRESSION = "expression"; // NOI18N        
}
