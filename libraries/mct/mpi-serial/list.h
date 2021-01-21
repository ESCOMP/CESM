/*
 *  (C) 2000 UNIVERSITY OF CHICAGO
 *      See COPYRIGHT in top-level directory.
 */





/******************************************************
 * WARNING: This file automatically generated.        *
 *          Do not edit by hand.                      *
 ******************************************************
 */




extern int AP_listitem_verify(void);
extern pListitem AP_listitem_prev(pListitem listitem);
extern pListitem AP_listitem_next(pListitem listitem);
extern void *AP_listitem_data(pListitem listitem);
extern pList AP_list_new(void);
extern void AP_list_free(pList list);
extern int AP_list_size(pList list);
extern pListitem AP_list_prepend(pList list, void *data);
extern pListitem AP_list_append(pList list, void *data);
extern int AP_list_delete(pList list, void *data);
extern void AP_list_delete_item(pList list, pListitem item);
extern pListitem AP_list_head_item(pList list);
extern int AP_list_head(pList list, void **data);
extern int AP_list_tail(pList list, void **data);
extern void AP_list_print(char *str, pList list);
extern void AP_list_revprint(char *str, pList list);
extern pListitem AP_list_search(pList list, void *data);
extern int AP_list_next(pList list, void **data, void **temp);
extern void *AP_list_braindead_next(pList list, void **temp);
extern pList AP_list_duplicate(pList list);


extern pListitem AP_list_search_func(pList list, int (*func)(void *i, void *j),void *data);

extern int AP_list_apply(pList list, int (*func)(void *item_data, void *fixed_data), void *data);


