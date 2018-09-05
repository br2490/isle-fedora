<?xml version='1.0' ?>
  <users>
    <user name="{{getv "/fedora/admin/user"}}" password="{{getv "/fedora/admin/pass"}}">
      <attribute name="fedoraRole">
        <value>administrator</value>
      </attribute>
    </user>
    <user name="{{getv "/fedora/intcall/user"}}" password="{{getv "/fedora/intcall/pass"}}">
      <attribute name="fedoraRole">
        <value>fedoraInternalCall-1</value>
        <value>fedoraInternalCall-2</value>
      </attribute>
    </user>
    <user name="{{getv "/fedora/gsearch/user"}}" password="{{getv "/fedora/gsearch/pass"}}">
      <attribute name="fedoraRole">
      <value>administrator</value>
    </attribute>
    </user>
    <user name="anonymous" password="anonymous">
    	<attribute name="fedoraRole">
      	<value>fedoraUser</value>
    </attribute>
  </user>
</users>
