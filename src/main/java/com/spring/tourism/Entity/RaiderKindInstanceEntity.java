package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "raider_kind_instance", schema = "public", catalog = "travel")
public class RaiderKindInstanceEntity {
    private int kindId;
    private String kindName;

    @Id
    @Column(name = "kind_id")
    public int getKindId() {
        return kindId;
    }

    public void setKindId(int kindId) {
        this.kindId = kindId;
    }

    @Basic
    @Column(name = "kind_name")
    public String getKindName() {
        return kindName;
    }

    public void setKindName(String kindName) {
        this.kindName = kindName;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        RaiderKindInstanceEntity that = (RaiderKindInstanceEntity) o;

        if (kindId != that.kindId) return false;
        if (!Objects.equals(kindName, that.kindName)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = kindId;
        result = 31 * result + (kindName != null ? kindName.hashCode() : 0);
        return result;
    }
}
